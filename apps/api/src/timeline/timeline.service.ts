import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { BlockFlexibility, BlockSource, MemberStatus, Visibility } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { GroupsService } from '../groups/groups.service';
import { expandRecurrence } from '../common/utils/recurrence';
import { redactBlock, BlockView } from '../common/utils/visibility';
import { CreateBlockDto, UpdateBlockDto } from './dto/timeline.dto';

const DAY = 24 * 60 * 60 * 1000;

type BlockWithMeta = {
  block: any;
  effective?: Visibility;
};

export type TimelineItem = BlockView & { instanceId: string };

@Injectable()
export class TimelineService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly groups: GroupsService,
  ) {}

  // ── Self timeline ─────────────────────────────────────────────────────────
  async listSelf(userId: string, from: Date, to: Date): Promise<{ items: TimelineItem[] }> {
    const blocks = await this.fetchBlocks({ ownerUserId: userId, from, to });
    const sources = blocks.map((block: any) => ({ block }));
    return { items: this.expandAndRedact(sources, userId, from, to) };
  }

  // ── Group timeline (privacy-redacted for the viewer) ──────────────────────
  async listGroup(userId: string, groupId: string, from: Date, to: Date) {
    await this.groups.requireMember(groupId, userId);
    const sources = await this.gatherGroupSources(groupId, from, to);
    const items = this.expandAndRedact(sources, userId, from, to);

    // Per-member availability for the "Members" view (busy-only, privacy-safe).
    const members = await this.prisma.groupMember.findMany({
      where: { groupId, status: MemberStatus.ACTIVE },
      include: { user: { select: { id: true, name: true, avatarUrl: true } } },
    });
    return { items, members: members.map((m) => ({ id: m.userId, name: m.user.name, avatarUrl: m.user.avatarUrl })) };
  }

  // ── Block CRUD ────────────────────────────────────────────────────────────
  async create(userId: string, dto: CreateBlockDto): Promise<any> {
    const start = new Date(dto.startTime);
    const end = new Date(dto.endTime);
    if (!(start < end)) throw new BadRequestException('Start must be before end');

    let groupId: string | null = null;
    let ownerUserId: string | null = userId;
    let visibility: Visibility = dto.visibility ?? Visibility.PRIVATE;
    let source: BlockSource = BlockSource.SELF;

    if (dto.groupId) {
      await this.groups.requirePermission(dto.groupId, userId, 'TIMELINE_CREATE');
      const group = await this.prisma.group.findUnique({ where: { id: dto.groupId } });
      if (!group) throw new NotFoundException('Group not found');
      const settings = (group.settings as unknown as { defaultVisibility?: Visibility }) ?? {};
      groupId = dto.groupId;
      ownerUserId = null;
      visibility = dto.visibility ?? (settings.defaultVisibility as Visibility) ?? Visibility.TITLE_ONLY;
      source = BlockSource.GROUP;
    }

    return this.persistBlock(
      userId,
      {
        title: dto.title,
        description: dto.description,
        startTime: start,
        endTime: end,
        allDay: dto.allDay,
        timezone: dto.timezone,
        flexibility: dto.flexibility,
        color: dto.color,
        location: dto.location,
        recurrenceRule: dto.recurrenceRule,
        reminderMinutesBefore: dto.reminderMinutesBefore,
        isEvent: dto.isEvent,
      },
      { groupId, ownerUserId, visibility, source },
    );
  }

  private async persistBlock(
    userId: string,
    fields: {
      title: string;
      description?: string | null;
      startTime: Date;
      endTime: Date;
      allDay?: boolean;
      timezone?: string;
      flexibility?: BlockFlexibility;
      color?: string;
      location?: string | null;
      recurrenceRule?: string | null;
      reminderMinutesBefore?: number | null;
      isEvent?: boolean;
    },
    ownership: { groupId: string | null; ownerUserId: string | null; visibility: Visibility; source: BlockSource },
  ) {
    const block = await this.prisma.timelineBlock.create({
      data: {
        ownerUserId: ownership.ownerUserId,
        groupId: ownership.groupId,
        title: fields.title,
        description: fields.description,
        startTime: fields.startTime,
        endTime: fields.endTime,
        timezone: fields.timezone ?? 'UTC',
        visibility: ownership.visibility,
        flexibility: fields.flexibility ?? BlockFlexibility.FIXED,
        source: ownership.source,
        color: fields.color ?? '#2563EB',
        location: fields.location,
        recurrenceRule: fields.recurrenceRule,
        reminderMinutesBefore: fields.reminderMinutesBefore,
        isEvent: fields.isEvent ?? false,
        allDay: fields.allDay ?? false,
        createdById: userId,
      },
    });
    await this.syncReminders(block);
    return this.toPrivateDto(block);
  }

  async update(userId: string, blockId: string, dto: UpdateBlockDto): Promise<any> {
    const block = await this.assertWritable(userId, blockId);
    // Validate the EFFECTIVE window by falling back to the persisted values, so
    // a partial PATCH that only changes one bound cannot break start<end.
    const start = dto.startTime ? new Date(dto.startTime) : block.startTime;
    const end = dto.endTime ? new Date(dto.endTime) : block.endTime;
    if (!(start < end)) throw new BadRequestException('Start must be before end');

    const updated = await this.prisma.timelineBlock.update({
      where: { id: blockId },
      data: {
        title: dto.title,
        description: dto.description,
        startTime: dto.startTime ? new Date(dto.startTime) : undefined,
        endTime: dto.endTime ? new Date(dto.endTime) : undefined,
        allDay: dto.allDay,
        visibility: dto.visibility,
        flexibility: dto.flexibility,
        color: dto.color,
        location: dto.location,
        recurrenceRule: dto.recurrenceRule,
        reminderMinutesBefore: dto.reminderMinutesBefore,
        isEvent: dto.isEvent,
      },
    });
    await this.syncReminders(updated);
    return this.toPrivateDto(updated);
  }

  async remove(userId: string, blockId: string) {
    const block = await this.assertWritable(userId, blockId);
    await this.prisma.$transaction([
      this.prisma.timelineBlock.update({ where: { id: blockId }, data: { deletedAt: new Date() } }),
      this.prisma.reminder.updateMany({
        where: { refId: blockId, refType: 'TIMELINE_BLOCK', status: 'SCHEDULED' },
        data: { status: 'CANCELLED' },
      }),
    ]);
    return { ok: true };
  }

  async getOne(userId: string, blockId: string) {
    const block = await this.prisma.timelineBlock.findUnique({ where: { id: blockId } });
    if (!block || block.deletedAt) throw new NotFoundException('Block not found');
    const isOwner = block.ownerUserId === userId || block.createdById === userId;
    let effective: Visibility | undefined;

    if (!isOwner) {
      if (block.groupId) {
        // Group block: visible to members; the block's own visibility governs.
        await this.groups.requireMember(block.groupId, userId);
      } else {
        // Self block of someone else → reachable only via a sync into a group the
        // viewer belongs to. Collect the viewer's eligible syncs and use the most
        // permissive one as the effective visibility (previously the sync's
        // visibility was ignored, leaking full details of shared PRIVATE blocks).
        const syncs = await this.prisma.timelineBlockSync.findMany({
          where: { timelineBlockId: blockId },
        });
        const viewerVisibilities: Visibility[] = [];
        for (const s of syncs) {
          if (await this.groups.isMember(s.groupId, userId)) viewerVisibilities.push(s.visibility);
        }
        if (!viewerVisibilities.length) throw new NotFoundException('Block not found');
        effective = this.mostPermissive(viewerVisibilities);
      }
    }

    const view = redactBlock(this.toRaw(block, undefined, undefined, effective), userId);
    if (!view) throw new NotFoundException('Block not found');
    return view;
  }

  private mostPermissive(visibilities: Visibility[]): Visibility {
    const rank: Record<Visibility, number> = {
      PRIVATE: 0,
      BUSY_ONLY: 1,
      TITLE_ONLY: 2,
      FULL: 3,
    };
    return visibilities.reduce((best, v) => (rank[v] > rank[best] ? v : best), Visibility.PRIVATE);
  }

  // ── Sync (the privacy feature: share a self block with groups) ────────────
  async listSyncs(userId: string, blockId: string) {
    const block = await this.assertOwned(userId, blockId);
    const syncs = await this.prisma.timelineBlockSync.findMany({
      where: { timelineBlockId: block.id },
    });
    return { syncs: syncs.map((s) => ({ groupId: s.groupId, visibility: s.visibility })) };
  }

  async sync(userId: string, blockId: string, entries: { groupId: string; visibility: Visibility }[]) {
    const block = await this.assertOwned(userId, blockId);
    for (const entry of entries) {
      await this.groups.requireMember(entry.groupId, userId);
    }
    // Upsert each sync.
    await Promise.all(
      entries.map((entry) =>
        this.prisma.timelineBlockSync.upsert({
          where: { timelineBlockId_groupId: { timelineBlockId: block.id, groupId: entry.groupId } },
          update: { visibility: entry.visibility },
          create: { timelineBlockId: block.id, groupId: entry.groupId, visibility: entry.visibility, syncedById: userId },
        }),
      ),
    );
    return this.listSyncs(userId, blockId);
  }

  async removeSync(userId: string, blockId: string, groupId: string) {
    const block = await this.assertOwned(userId, blockId);
    await this.prisma.timelineBlockSync.deleteMany({ where: { timelineBlockId: block.id, groupId } });
    return { ok: true };
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  private async assertOwned(userId: string, blockId: string) {
    const block = await this.prisma.timelineBlock.findUnique({ where: { id: blockId } });
    if (!block || block.deletedAt) throw new NotFoundException('Block not found');
    if (block.ownerUserId !== userId) throw new ForbiddenException('Only the owner can manage sync settings');
    return block;
  }

  private async assertWritable(userId: string, blockId: string) {
    const block = await this.prisma.timelineBlock.findUnique({ where: { id: blockId } });
    if (!block || block.deletedAt) throw new NotFoundException('Block not found');
    if (block.ownerUserId === userId || block.createdById === userId) return block;
    if (block.groupId) {
      // group block: admins may edit any, others only their own (already checked)
      await this.groups.requirePermission(block.groupId, userId, 'TIMELINE_UPDATE_ANY');
      return block;
    }
    throw new ForbiddenException('Not allowed to edit this block');
  }

  private async fetchBlocks(where: { ownerUserId: string; from: Date; to: Date }) {
    return this.prisma.timelineBlock.findMany({
      where: {
        ownerUserId: where.ownerUserId,
        deletedAt: null,
        startTime: { lte: new Date(where.to.getTime() + DAY) },
        OR: [{ recurrenceRule: { not: null } }, { endTime: { gte: new Date(where.from.getTime() - DAY) } }],
      },
      orderBy: { startTime: 'asc' },
    });
  }

  private async gatherGroupSources(groupId: string, from: Date, to: Date): Promise<BlockWithMeta[]> {
    const [groupBlocks, syncs] = await Promise.all([
      this.prisma.timelineBlock.findMany({
        where: {
          groupId,
          deletedAt: null,
          startTime: { lte: new Date(to.getTime() + DAY) },
          OR: [{ recurrenceRule: { not: null } }, { endTime: { gte: new Date(from.getTime() - DAY) } }],
        },
      }),
      this.prisma.timelineBlockSync.findMany({
        where: { groupId },
        include: { block: true },
      }),
    ]);

    const sources: BlockWithMeta[] = groupBlocks.map((block) => ({ block }));
    for (const s of syncs) {
      if (!s.block || s.block.deletedAt) continue;
      if (s.block.startTime > new Date(to.getTime() + DAY)) continue;
      if (!s.block.recurrenceRule && s.block.endTime < new Date(from.getTime() - DAY)) continue;
      sources.push({ block: s.block, effective: s.visibility });
    }
    return sources;
  }

  private expandAndRedact(sources: BlockWithMeta[], viewerId: string, from: Date, to: Date): TimelineItem[] {
    const out: TimelineItem[] = [];
    for (const { block, effective } of sources) {
      const occurrences = expandRecurrence(block, from, to);
      for (const occ of occurrences) {
        const raw = this.toRaw(block, occ.start, occ.end, effective);
        const view = redactBlock(raw, viewerId);
        if (view) out.push({ ...view, instanceId: `${block.id}:${occ.start.getTime()}` });
      }
    }
    return out.sort((a, b) => new Date(a.startTime).getTime() - new Date(b.startTime).getTime());
  }

  private toRaw(block: any, start?: Date, end?: Date, effective?: Visibility) {
    return {
      id: block.id,
      title: block.title,
      description: block.description,
      startTime: start ?? block.startTime,
      endTime: end ?? block.endTime,
      color: block.color,
      location: block.location,
      visibility: block.visibility,
      ownerId: block.ownerUserId,
      groupId: block.groupId,
      createdById: block.createdById,
      isEvent: block.isEvent,
      allDay: block.allDay,
      source: block.source,
      reminderMinutesBefore: block.reminderMinutesBefore,
      effectiveVisibility: effective,
    };
  }

  private toPrivateDto(block: any) {
    return {
      id: block.id,
      title: block.title,
      description: block.description,
      startTime: block.startTime.toISOString ? block.startTime.toISOString() : new Date(block.startTime).toISOString(),
      endTime: block.endTime.toISOString ? block.endTime.toISOString() : new Date(block.endTime).toISOString(),
      timezone: block.timezone,
      visibility: block.visibility,
      flexibility: block.flexibility,
      color: block.color,
      location: block.location,
      recurrenceRule: block.recurrenceRule,
      isEvent: block.isEvent,
      allDay: block.allDay,
      source: block.source,
      groupId: block.groupId,
      reminderMinutesBefore: block.reminderMinutesBefore,
    };
  }

  private async syncReminders(block: any) {
    await this.prisma.reminder.updateMany({
      where: { refId: block.id, refType: 'TIMELINE_BLOCK', status: 'SCHEDULED' },
      data: { status: 'CANCELLED' },
    });
    if (block.reminderMinutesBefore == null) return;

    const userIds: string[] = block.groupId
      ? (await this.prisma.groupMember.findMany({
          where: { groupId: block.groupId, status: MemberStatus.ACTIVE },
          select: { userId: true },
        })).map((m) => m.userId)
      : block.ownerUserId
        ? [block.ownerUserId]
        : [];

    const next = this.nextOccurrence(block);
    if (!next) return;
    const remindAt = new Date(next.getTime() - block.reminderMinutesBefore * 60_000);
    if (remindAt <= new Date()) return;

    if (userIds.length) {
      await this.prisma.reminder.createMany({
        data: userIds.map((userId) => ({
          userId,
          refType: 'TIMELINE_BLOCK',
          refId: block.id,
          remindAt,
          status: 'SCHEDULED',
          title: block.title,
          body: `Upcoming: ${block.title}`,
        })),
      });
    }
  }

  private nextOccurrence(block: any): Date | null {
    const now = new Date();
    if (block.recurrenceRule) {
      const occurrences = expandRecurrence(block, now, new Date(now.getTime() + 60 * DAY));
      return occurrences.length ? occurrences[0].start : null;
    }
    return block.startTime >= now ? block.startTime : null;
  }
}
