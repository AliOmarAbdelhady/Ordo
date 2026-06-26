import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { toPublicUser } from '../auth/auth.service';
import { UpdateProfileDto, UpdatePreferencesDto, UpdateAvailabilityDto } from './dto/user.dto';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async me(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');
    return toPublicUser(user);
  }

  async updateProfile(userId: string, dto: UpdateProfileDto) {
    if (dto.username) {
      const clash = await this.prisma.user.findFirst({
        where: { username: dto.username, NOT: { id: userId } },
        select: { id: true },
      });
      if (clash) throw new ConflictException('Username already taken');
    }
    const user = await this.prisma.user.update({
      where: { id: userId },
      data: {
        name: dto.name,
        bio: dto.bio,
        avatarUrl: dto.avatarUrl,
        username: dto.username,
        timezone: dto.timezone,
      },
    });
    return toPublicUser(user);
  }

  async updatePreferences(userId: string, dto: UpdatePreferencesDto) {
    const user = await this.prisma.user.update({
      where: { id: userId },
      data: { theme: dto.theme, accentColor: dto.accentColor },
    });
    return toPublicUser(user);
  }

  async getAvailability(userId: string) {
    const prefs = await this.prisma.availabilityPreferences.findUnique({ where: { userId } });
    return (
      prefs ?? {
        userId,
        timezone: 'UTC',
        workStart: '09:00',
        workEnd: '17:00',
        sleepStart: '23:00',
        sleepEnd: '07:00',
        weekdays: [1, 2, 3, 4, 5],
      }
    );
  }

  async updateAvailability(userId: string, dto: UpdateAvailabilityDto) {
    const prefs = await this.prisma.availabilityPreferences.upsert({
      where: { userId },
      update: {
        timezone: dto.timezone,
        workStart: dto.workStart,
        workEnd: dto.workEnd,
        sleepStart: dto.sleepStart,
        sleepEnd: dto.sleepEnd,
        weekdays: dto.weekdays,
      },
      create: {
        userId,
        timezone: dto.timezone ?? 'UTC',
        workStart: dto.workStart ?? '09:00',
        workEnd: dto.workEnd ?? '17:00',
        sleepStart: dto.sleepStart ?? '23:00',
        sleepEnd: dto.sleepEnd ?? '07:00',
        weekdays: dto.weekdays ?? [1, 2, 3, 4, 5],
      },
    });
    return prefs;
  }

  async deleteAccount(userId: string) {
    await this.prisma.user.update({
      where: { id: userId },
      data: { deletedAt: new Date() },
    });
    await this.prisma.session.updateMany({
      where: { userId },
      data: { revokedAt: new Date() },
    });
    return { ok: true };
  }

  /** GDPR-style data export: everything the user owns or is a member of. */
  async exportData(userId: string) {
    const memberships = await this.prisma.groupMember.findMany({
      where: { userId, status: 'ACTIVE' },
      select: { groupId: true },
    });
    const groupIds = memberships.map((m) => m.groupId);

    const [user, groups, blocks, tasks, todos, messages, membershipsRows, availability] = await Promise.all([
      this.prisma.user.findUnique({ where: { id: userId } }),
      this.prisma.group.findMany({ where: { id: { in: groupIds } } }),
      // Blocks the user owns or authored (self blocks + group blocks they created).
      this.prisma.timelineBlock.findMany({
        where: { OR: [{ ownerUserId: userId }, { createdById: userId }], deletedAt: null },
        take: 1000,
      }),
      // Tasks the user authored or is assigned to — not every task in every group.
      this.prisma.task.findMany({
        where: {
          groupId: { in: groupIds },
          deletedAt: null,
          OR: [{ createdById: userId }, { assignees: { some: { userId } } }],
        },
        take: 1000,
      }),
      // To-dos the user owns or authored — not every group to-do.
      this.prisma.todo.findMany({
        where: { OR: [{ ownerUserId: userId }, { createdById: userId }] },
        take: 1000,
      }),
      this.prisma.message.findMany({ where: { senderId: userId, deletedAt: null }, take: 1000 }),
      this.prisma.groupMember.findMany({ where: { userId }, include: { group: true } }),
      this.prisma.availabilityPreferences.findUnique({ where: { userId } }),
    ]);

    return {
      exportedAt: new Date().toISOString(),
      user: user
        ? {
            id: user.id,
            email: user.email,
            phone: user.phone,
            name: user.name,
            username: user.username,
            bio: user.bio,
            timezone: user.timezone,
            createdAt: user.createdAt.toISOString(),
          }
        : null,
      availability,
      groups,
      memberships: membershipsRows,
      timelineBlocks: blocks,
      tasks,
      todos,
      messages: messages.map((m) => ({ id: m.id, groupId: m.groupId, body: m.body, createdAt: m.createdAt })),
    };
  }
}
