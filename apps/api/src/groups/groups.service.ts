import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { GroupMember, GroupRole, GroupType, MemberStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { Permission, can } from '../common/permissions';
import {
  GROUP_TEMPLATES,
  GROUP_TYPES,
  GroupModules,
  templateFor,
  ALL_MODULES_OFF,
} from './group-templates';
import { CreateGroupDto, UpdateGroupDto } from './dto/group.dto';

export interface PublicGroup {
  id: string;
  name: string;
  type: GroupType;
  description: string | null;
  avatarUrl: string | null;
  accentColor: string;
  settings: Record<string, unknown>;
  modules: GroupModules;
  createdAt: string;
  role: GroupRole;
  memberCount: number;
  pendingTaskCount: number;
  unreadCount: number;
  nextEvent: { id: string; title: string; startTime: string } | null;
  pinned: boolean;
}

@Injectable()
export class GroupsService {
  constructor(private readonly prisma: PrismaService) {}

  // ── Templates ──────────────────────────────────────────────────────────────
  templates() {
    return GROUP_TYPES;
  }

  // ── Membership helpers (used across modules) ──────────────────────────────
  async requireMember(groupId: string, userId: string): Promise<GroupMember> {
    const membership = await this.prisma.groupMember.findFirst({
      where: { groupId, userId, status: MemberStatus.ACTIVE },
    });
    if (!membership) throw new NotFoundException('Group not found');
    return membership;
  }

  async requirePermission(groupId: string, userId: string, permission: Permission): Promise<GroupMember> {
    const membership = await this.requireMember(groupId, userId);
    if (!can(membership.role, permission)) {
      throw new ForbiddenException('You do not have permission to do that');
    }
    return membership;
  }

  /** Returns true if the user is an active member of the group. */
  async isMember(groupId: string, userId: string): Promise<boolean> {
    const m = await this.prisma.groupMember.findFirst({
      where: { groupId, userId, status: MemberStatus.ACTIVE },
      select: { id: true },
    });
    return !!m;
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────
  async create(userId: string, dto: CreateGroupDto): Promise<PublicGroup> {
    const type = dto.type ?? GroupType.CUSTOM;
    const tpl = templateFor(type);
    const modules: GroupModules = { ...tpl.modules, ...(dto.modules ?? {}) };
    const settings = {
      modules,
      defaultVisibility: tpl.defaultVisibility,
      allowMemberTimeline: true,
      allowMemberTasks: true,
    };

    const group = await this.prisma.group.create({
      data: {
        name: dto.name,
        type,
        description: dto.description,
        avatarUrl: dto.avatarUrl,
        accentColor: dto.accentColor ?? tpl.accentColor,
        settings: settings as unknown as Prisma.InputJsonValue,
        createdById: userId,
        members: {
          create: { userId, role: GroupRole.OWNER, status: MemberStatus.ACTIVE },
        },
      },
    });

    return this.toPublicGroup(group, GroupRole.OWNER, userId);
  }

  async list(userId: string, type?: GroupType): Promise<PublicGroup[]> {
    const memberships = await this.prisma.groupMember.findMany({
      where: { userId, status: MemberStatus.ACTIVE },
      include: { group: true },
      orderBy: { pinned: 'desc' },
    });

    const groups = memberships
      .filter((m) => m.group && (!type || m.group.type === type))
      .map((m) => ({ group: m.group!, role: m.role, pinned: m.pinned, lastReadAt: m.lastReadAt }));

    return Promise.all(
      groups.map((g) => this.toPublicGroup(g.group, g.role, userId, g.pinned, g.lastReadAt)),
    );
  }

  async get(userId: string, groupId: string) {
    const membership = await this.requireMember(groupId, userId);
    const group = await this.prisma.group.findUnique({ where: { id: groupId } });
    if (!group) throw new NotFoundException('Group not found');

    const members = await this.prisma.groupMember.findMany({
      where: { groupId, status: MemberStatus.ACTIVE },
      include: { user: { select: { id: true, name: true, username: true, avatarUrl: true } } },
      orderBy: [{ role: 'desc' }, { joinedAt: 'asc' }],
    });

    const pub = await this.toPublicGroup(group, membership.role, userId, membership.pinned, membership.lastReadAt);
    return {
      ...pub,
      members: members.map((m) => ({
        id: m.id,
        userId: m.userId,
        role: m.role,
        joinedAt: m.joinedAt.toISOString(),
        user: m.user,
      })),
    };
  }

  async update(userId: string, groupId: string, dto: UpdateGroupDto): Promise<PublicGroup> {
    await this.requirePermission(groupId, userId, 'GROUP_UPDATE');
    const existing = await this.prisma.group.findUnique({ where: { id: groupId } });
    if (!existing) throw new NotFoundException('Group not found');

    const settings = (existing.settings as unknown as { modules?: GroupModules; defaultVisibility?: string }) ?? {};
    const mergedSettings = dto.modules
      ? {
          ...settings,
          modules: { ...(settings.modules as GroupModules | undefined), ...(dto.modules as unknown as GroupModules) },
        }
      : settings;

    const group = await this.prisma.group.update({
      where: { id: groupId },
      data: {
        name: dto.name,
        description: dto.description,
        avatarUrl: dto.avatarUrl,
        accentColor: dto.accentColor,
        ...(dto.modules ? { settings: mergedSettings as unknown as Prisma.InputJsonValue } : {}),
      },
    });
    const membership = await this.requireMember(groupId, userId);
    return this.toPublicGroup(group, membership.role, userId, membership.pinned, membership.lastReadAt);
  }

  async remove(userId: string, groupId: string) {
    await this.requirePermission(groupId, userId, 'GROUP_DELETE');
    await this.prisma.group.delete({ where: { id: groupId } });
    return { ok: true };
  }

  async invite(userId: string, groupId: string) {
    await this.requirePermission(groupId, userId, 'MEMBER_INVITE');
    const invite = await this.prisma.groupInvite.create({
      data: { groupId, createdBy: userId, maxUses: 0, expiresAt: null },
    });
    return { code: invite.code };
  }

  async joinByCode(userId: string, code: string) {
    const invite = await this.prisma.groupInvite.findUnique({ where: { code } });
    if (!invite) throw new NotFoundException('Invite not found');
    if (invite.expiresAt && invite.expiresAt < new Date()) {
      throw new NotFoundException('Invite has expired');
    }

    const existing = await this.prisma.groupMember.findFirst({
      where: { groupId: invite.groupId, userId },
    });
    if (existing) {
      if (existing.status === MemberStatus.ACTIVE) throw new ForbiddenException('Already a member');
      await this.prisma.groupMember.update({ where: { id: existing.id }, data: { status: MemberStatus.ACTIVE } });
    } else {
      await this.prisma.groupMember.create({
        data: { groupId: invite.groupId, userId, role: GroupRole.MEMBER, status: MemberStatus.ACTIVE },
      });
    }
    await this.prisma.groupInvite.update({
      where: { id: invite.id },
      data: { uses: { increment: 1 } },
    });
    return { groupId: invite.groupId };
  }

  async listMembers(userId: string, groupId: string) {
    await this.requireMember(groupId, userId);
    const members = await this.prisma.groupMember.findMany({
      where: { groupId, status: MemberStatus.ACTIVE },
      include: { user: { select: { id: true, name: true, username: true, avatarUrl: true } } },
      orderBy: [{ role: 'desc' }, { joinedAt: 'asc' }],
    });
    return { members: members.map((m) => ({ id: m.id, userId: m.userId, role: m.role, joinedAt: m.joinedAt.toISOString(), user: m.user })) };
  }

  async updateMember(userId: string, groupId: string, memberId: string, role: GroupRole) {
    const actor = await this.requirePermission(groupId, userId, 'MEMBER_ROLE_UPDATE');
    const target = await this.prisma.groupMember.findFirst({ where: { id: memberId, groupId } });
    if (!target) throw new NotFoundException('Member not found');
    if (target.role === GroupRole.OWNER) throw new ForbiddenException('Cannot change the owner role directly');

    if (role === GroupRole.OWNER) {
      // ownership transfer
      await this.prisma.$transaction([
        this.prisma.groupMember.update({ where: { id: actor.id }, data: { role: GroupRole.ADMIN } }),
        this.prisma.groupMember.update({ where: { id: target.id }, data: { role: GroupRole.OWNER } }),
      ]);
    } else {
      await this.prisma.groupMember.update({ where: { id: target.id }, data: { role } });
    }
    return { ok: true };
  }

  async removeMember(userId: string, groupId: string, memberId: string) {
    await this.requirePermission(groupId, userId, 'MEMBER_REMOVE');
    const target = await this.prisma.groupMember.findFirst({ where: { id: memberId, groupId } });
    if (!target) throw new NotFoundException('Member not found');
    if (target.role === GroupRole.OWNER) throw new ForbiddenException('Cannot remove the owner');

    // If acting on self this is a "leave".
    if (target.userId === userId) return this.leave(userId, groupId);

    await this.prisma.groupMember.update({ where: { id: target.id }, data: { status: MemberStatus.REMOVED } });
    return { ok: true };
  }

  async leave(userId: string, groupId: string) {
    const membership = await this.requireMember(groupId, userId);
    if (membership.role === GroupRole.OWNER) {
      // Auto-transfer to the longest-tenured active member, or delete the group.
      const next = await this.prisma.groupMember.findFirst({
        where: { groupId, status: MemberStatus.ACTIVE, userId: { not: userId } },
        orderBy: { joinedAt: 'asc' },
      });
      if (!next) {
        await this.prisma.group.delete({ where: { id: groupId } });
        return { ok: true, deleted: true };
      }
      await this.prisma.$transaction([
        this.prisma.groupMember.update({ where: { id: next.id }, data: { role: GroupRole.OWNER } }),
        this.prisma.groupMember.update({ where: { id: membership.id }, data: { status: MemberStatus.LEFT } }),
      ]);
      return { ok: true };
    }
    await this.prisma.groupMember.update({ where: { id: membership.id }, data: { status: MemberStatus.LEFT } });
    return { ok: true };
  }

  async setPinned(userId: string, groupId: string, pinned: boolean) {
    await this.requireMember(groupId, userId);
    const m = await this.prisma.groupMember.findFirst({ where: { groupId, userId } });
    await this.prisma.groupMember.update({ where: { id: m!.id }, data: { pinned } });
    return { ok: true };
  }

  async markRead(userId: string, groupId: string) {
    const m = await this.requireMember(groupId, userId);
    await this.prisma.groupMember.update({ where: { id: m.id }, data: { lastReadAt: new Date() } });
    return { ok: true };
  }

  // ── Serialization ─────────────────────────────────────────────────────────
  private async toPublicGroup(
    group: { id: string; name: string; type: GroupType; description: string | null; avatarUrl: string | null; accentColor: string; settings: Prisma.JsonValue; createdAt: Date },
    role: GroupRole,
    userId: string,
    pinned = false,
    lastReadAt?: Date | null,
  ): Promise<PublicGroup> {
    const settings = (group.settings as unknown as { modules?: GroupModules }) ?? {};
    const modules: GroupModules = { ...ALL_MODULES_OFF, ...(settings.modules as GroupModules | undefined) } as GroupModules;

    const [memberCount, pendingTaskCount, unreadCount, nextEvent] = await Promise.all([
      this.prisma.groupMember.count({ where: { groupId: group.id, status: MemberStatus.ACTIVE } }),
      this.prisma.task.count({
        where: { groupId: group.id, status: { in: ['TODO', 'IN_PROGRESS', 'BLOCKED'] }, deletedAt: null },
      }),
      lastReadAt
        ? this.prisma.message.count({
            where: { groupId: group.id, createdAt: { gt: lastReadAt }, senderId: { not: userId }, deletedAt: null },
          })
        : 0,
      this.nextEvent(group.id),
    ]);

    return {
      id: group.id,
      name: group.name,
      type: group.type,
      description: group.description,
      avatarUrl: group.avatarUrl,
      accentColor: group.accentColor,
      settings: settings as Record<string, unknown>,
      modules,
      createdAt: group.createdAt.toISOString(),
      role,
      memberCount,
      pendingTaskCount,
      unreadCount,
      nextEvent: nextEvent
        ? { id: nextEvent.id, title: nextEvent.title, startTime: nextEvent.startTime.toISOString() }
        : null,
      pinned,
    };
  }

  private async nextEvent(groupId: string) {
    const now = new Date();
    return this.prisma.timelineBlock.findFirst({
      where: { groupId, startTime: { gte: now }, deletedAt: null },
      orderBy: { startTime: 'asc' },
      select: { id: true, title: true, startTime: true },
    });
  }

  templateList() {
    return GROUP_TEMPLATES;
  }
}
