import { Injectable } from '@nestjs/common';
import { MemberStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { GroupsService } from '../groups/groups.service';
import { expandRecurrence } from '../common/utils/recurrence';
import { findFreeSlots, MemberAvailability, SlotResult, hhmmToMinutes } from '../common/utils/slots';
import { Interval } from '../common/utils/time';
import { FindSlotsDto } from './dto/availability.dto';

const DAY = 24 * 60 * 60 * 1000;

@Injectable()
export class AvailabilityService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly groups: GroupsService,
  ) {}

  async findSlots(userId: string, dto: FindSlotsDto) {
    await this.groups.requireMember(dto.groupId, userId);
    const from = new Date(dto.dateRangeStart);
    const to = new Date(dto.dateRangeEnd);

    // Bound the window to keep the grid search fast.
    const cappedTo = to.getTime() - from.getTime() > 14 * DAY ? new Date(from.getTime() + 14 * DAY) : to;

    const members = await this.prisma.groupMember.findMany({
      where: { groupId: dto.groupId, status: MemberStatus.ACTIVE },
      include: { user: { select: { id: true, name: true, avatarUrl: true, timezone: true } } },
    });

    const memberAvailability: MemberAvailability[] = [];
    for (const m of members) {
      const intervals = await this.memberBusyFull(m.userId, from, cappedTo);
      const prefs = await this.prisma.availabilityPreferences.findUnique({ where: { userId: m.userId } });
      memberAvailability.push({
        memberId: m.userId,
        intervals,
        timezone: prefs?.timezone ?? m.user.timezone ?? 'UTC',
        sleepStartMin: prefs ? hhmmToMinutes(prefs.sleepStart) : hhmmToMinutes('23:00'),
        sleepEndMin: prefs ? hhmmToMinutes(prefs.sleepEnd) : hhmmToMinutes('07:00'),
        weekdays: prefs?.weekdays ?? [1, 2, 3, 4, 5],
      });
    }

    const required = dto.requiredMemberIds ?? [];
    const minimum = dto.minimumAvailableCount ?? Math.max(1, required.length);

    const slots: SlotResult[] = findFreeSlots({
      rangeStart: from,
      rangeEnd: cappedTo,
      durationMinutes: dto.durationMinutes,
      members: memberAvailability,
      requiredMemberIds: required,
      minimumAvailableCount: minimum,
      preferredTimeWindows: dto.preferredTimeWindows ?? [],
      timezone: dto.timezone ?? 'UTC',
    });

    return {
      slots,
      members: members.map((m) => ({ id: m.userId, name: m.user.name, avatarUrl: m.user.avatarUrl })),
      totalMembers: members.length,
    };
  }

  /** Privacy-safe per-member busy intervals for the "Members" availability strip. */
  async groupAvailabilityStrip(userId: string, groupId: string, from: Date, to: Date) {
    await this.groups.requireMember(groupId, userId);
    const members = await this.prisma.groupMember.findMany({
      where: { groupId, status: MemberStatus.ACTIVE },
      include: { user: { select: { id: true, name: true, avatarUrl: true } } },
    });

    const out = await Promise.all(
      members.map(async (m) => {
        const intervals = await this.memberBusyForGroup(m.userId, groupId, from, to);
        return {
          id: m.userId,
          name: m.user.name,
          avatarUrl: m.user.avatarUrl,
          busy: intervals.map((i) => ({ start: i.start.toISOString(), end: i.end.toISOString() })),
        };
      }),
    );
    return { members: out };
  }

  /**
   * A member's REAL busy intervals across their whole calendar (self blocks +
   * every group they are in + synced blocks). Used by findSlots, which consumes
   * these SERVER-SIDE to compute free slots — the busy intervals themselves are
   * never returned to the requester, so no cross-group timing is leaked. This
   * must stay complete or findSlots would suggest times when members are busy.
   */
  private async memberBusyFull(userId: string, from: Date, to: Date): Promise<Interval[]> {
    const groupIds = (
      await this.prisma.groupMember.findMany({
        where: { userId, status: MemberStatus.ACTIVE },
        select: { groupId: true },
      })
    ).map((g) => g.groupId);

    const window = {
      deletedAt: null,
      startTime: { lte: new Date(to.getTime() + DAY) },
      OR: [{ recurrenceRule: { not: null } }, { endTime: { gte: new Date(from.getTime() - DAY) } }],
    };

    const [selfBlocks, groupBlocks, syncs] = await Promise.all([
      this.prisma.timelineBlock.findMany({ where: { ownerUserId: userId, ...window } }),
      groupIds.length
        ? this.prisma.timelineBlock.findMany({ where: { groupId: { in: groupIds }, ...window } })
        : Promise.resolve([]),
      groupIds.length
        ? this.prisma.timelineBlockSync.findMany({ where: { groupId: { in: groupIds }, block: window }, include: { block: true } })
        : Promise.resolve([]),
    ]);

    const sources = [
      ...selfBlocks,
      ...groupBlocks,
      ...syncs.filter((s) => s.block && !s.block.deletedAt && s.block.ownerUserId === userId).map((s) => s.block),
    ];

    const intervals: Interval[] = [];
    for (const b of sources) intervals.push(...expandRecurrence(b as any, from, to));
    return this.mergeIntervals(intervals);
  }

  /**
   * Privacy-safe busy intervals for a member WITHIN a specific group context, for
   * the "Members" availability STRIP (which DISPLAYS busy intervals to viewers).
   * Returns only: (a) that group's blocks (they block every member) and (b) the
   * member's own self-blocks explicitly synced into this group. It deliberately
   * omits the member's private self-blocks and other-group blocks so a viewer in
   * one group cannot see the timing of commitments from groups they don't share.
   * Timing-only intervals are the intended BUSY_ONLY representation (no titles).
   */
  private async memberBusyForGroup(userId: string, groupId: string, from: Date, to: Date): Promise<Interval[]> {
    const window = {
      deletedAt: null,
      startTime: { lte: new Date(to.getTime() + DAY) },
      OR: [{ recurrenceRule: { not: null } }, { endTime: { gte: new Date(from.getTime() - DAY) } }],
    };

    const [groupBlocks, syncs] = await Promise.all([
      this.prisma.timelineBlock.findMany({ where: { groupId, ...window } }),
      this.prisma.timelineBlockSync.findMany({
        where: { groupId, block: window },
        include: { block: true },
      }),
    ]);

    const sources = [
      ...groupBlocks,
      // Only this member's synced self-blocks make THEM busy.
      ...syncs
        .filter((s) => s.block && !s.block.deletedAt && s.block.ownerUserId === userId)
        .map((s) => s.block),
    ];

    const intervals: Interval[] = [];
    for (const b of sources) intervals.push(...expandRecurrence(b as any, from, to));
    return this.mergeIntervals(intervals);
  }

  private mergeIntervals(intervals: Interval[]): Interval[] {
    if (!intervals.length) return [];
    const sorted = [...intervals].sort((a, b) => a.start.getTime() - b.start.getTime());
    const merged: Interval[] = [sorted[0]];
    for (let i = 1; i < sorted.length; i++) {
      const last = merged[merged.length - 1];
      if (sorted[i].start <= last.end) {
        last.end = new Date(Math.max(last.end.getTime(), sorted[i].end.getTime()));
      } else {
        merged.push(sorted[i]);
      }
    }
    return merged;
  }
}
