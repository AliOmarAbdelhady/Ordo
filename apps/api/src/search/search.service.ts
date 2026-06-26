import { Injectable } from '@nestjs/common';
import { Visibility } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { redactBlock } from '../common/utils/visibility';

const PER_TYPE = 10;

@Injectable()
export class SearchService {
  constructor(private readonly prisma: PrismaService) {}

  async search(userId: string, query: string) {
    const q = query.trim();
    if (q.length < 2) {
      return { query: q, groups: [], tasks: [], todos: [], messages: [], blocks: [] };
    }

    const memberships = await this.prisma.groupMember.findMany({
      where: { userId, status: 'ACTIVE' },
      select: { groupId: true },
    });
    const groupIds = memberships.map((m) => m.groupId);

    const [groups, tasks, todos, messages, blocks] = await Promise.all([
      // Groups the user belongs to.
      this.prisma.group.findMany({
        where: {
          id: { in: groupIds },
          OR: [{ name: { contains: q, mode: 'insensitive' } }, { description: { contains: q, mode: 'insensitive' } }],
        },
        take: PER_TYPE,
        orderBy: { name: 'asc' },
        select: { id: true, name: true, type: true, avatarUrl: true, accentColor: true },
      }),
      // Tasks in the user's groups.
      groupIds.length
        ? this.prisma.task.findMany({
            where: { groupId: { in: groupIds }, deletedAt: null, title: { contains: q, mode: 'insensitive' } },
            take: PER_TYPE,
            orderBy: { updatedAt: 'desc' },
            select: { id: true, title: true, status: true, priority: true, groupId: true, dueAt: true },
          })
        : [],
      // Todos: personal + the user's groups.
      this.prisma.todo.findMany({
        where: {
          OR: [{ ownerUserId: userId }, { groupId: { in: groupIds } }],
          title: { contains: q, mode: 'insensitive' },
        },
        take: PER_TYPE,
        orderBy: { updatedAt: 'desc' },
        select: { id: true, title: true, done: true, dueAt: true, ownerUserId: true, groupId: true },
      }),
      // Messages in the user's groups (bodies only — never reveal private timeline detail).
      groupIds.length
        ? this.prisma.message.findMany({
            where: { groupId: { in: groupIds }, deletedAt: null, body: { contains: q, mode: 'insensitive' } },
            take: PER_TYPE,
            orderBy: { createdAt: 'desc' },
            select: {
              id: true,
              body: true,
              createdAt: true,
              groupId: true,
              sender: { select: { id: true, name: true, avatarUrl: true } },
            },
          })
        : [],
      // Timeline blocks the viewer is allowed to see by title. PRIVATE blocks of
      // others are excluded outright; BUSY_ONLY matches are dropped too (surfacing
      // "Busy" for a title query would leak that a match exists). Each hit is still
      // run through redactBlock before leaving the server.
      this.searchBlocks(userId, groupIds, q),
    ]);

    return {
      query: q,
      groups,
      tasks,
      todos,
      messages: messages.map((m) => ({
        ...m,
        body: m.body ? (m.body.length > 160 ? m.body.slice(0, 160) + '…' : m.body) : null,
        createdAt: (m as any).createdAt.toISOString ? (m as any).createdAt.toISOString() : m.createdAt,
      })),
      blocks,
    };
  }

  private async searchBlocks(userId: string, groupIds: string[], needle: string) {
    const own = await this.prisma.timelineBlock.findMany({
      where: { ownerUserId: userId, deletedAt: null, title: { contains: needle, mode: 'insensitive' } },
      take: PER_TYPE,
    });
    const groupBlocks = groupIds.length
      ? await this.prisma.timelineBlock.findMany({
          where: {
            groupId: { in: groupIds },
            deletedAt: null,
            visibility: { in: [Visibility.TITLE_ONLY, Visibility.FULL] },
            title: { contains: needle, mode: 'insensitive' },
          },
          take: PER_TYPE,
        })
      : [];
    const seen = new Set<string>();
    const out: any[] = [];
    for (const b of [...own, ...groupBlocks]) {
      if (seen.has(b.id)) continue;
      seen.add(b.id);
      const view = redactBlock(
        {
          id: b.id,
          title: b.title,
          description: b.description,
          startTime: b.startTime,
          endTime: b.endTime,
          color: b.color,
          location: b.location,
          visibility: b.visibility,
          ownerId: b.ownerUserId,
          groupId: b.groupId,
          createdById: b.createdById,
          isEvent: b.isEvent,
          allDay: b.allDay,
          source: b.source,
          reminderMinutesBefore: b.reminderMinutesBefore,
        },
        userId,
      );
      if (view) out.push(view);
    }
    return out;
  }
}
