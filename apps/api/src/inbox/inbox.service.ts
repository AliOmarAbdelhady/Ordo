import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { MemberStatus, NotificationType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { CreateThreadDto, ListDmDto, SendDmDto } from './dto/inbox.dto';

@Injectable()
export class InboxService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
    private readonly realtime: RealtimeGateway,
  ) {}

  /** Two users may DM only when they share at least one active group membership. */
  private async assertShareGroup(a: string, b: string): Promise<void> {
    if (a === b) throw new BadRequestException('Cannot start a conversation with yourself');
    const shared = await this.prisma.groupMember.findFirst({
      where: {
        userId: a,
        status: MemberStatus.ACTIVE,
        group: { members: { some: { userId: b, status: MemberStatus.ACTIVE } } },
      },
      select: { id: true },
    });
    if (!shared) throw new ForbiddenException('You can only message people in your groups');
  }

  async findOrCreateThread(userId: string, dto: CreateThreadDto) {
    await this.assertShareGroup(userId, dto.otherUserId);

    const existing = await this.prisma.dmThread.findFirst({
      where: {
        AND: [
          { members: { some: { userId } } },
          { members: { some: { userId: dto.otherUserId } } },
        ],
      },
    });
    if (existing) {
      // Un-hide for the user if they had previously hidden it.
      await this.prisma.dmMember.updateMany({
        where: { threadId: existing.id, userId, hiddenAt: { not: null } },
        data: { hiddenAt: null },
      });
      return { threadId: existing.id };
    }

    const thread = await this.prisma.dmThread.create({
      data: {
        members: { create: [{ userId }, { userId: dto.otherUserId }] },
      },
    });
    return { threadId: thread.id };
  }

  async listThreads(userId: string) {
    const memberships = await this.prisma.dmMember.findMany({
      where: { userId, hiddenAt: null },
      include: {
        thread: {
          include: {
            members: { include: { user: { select: { id: true, name: true, username: true, avatarUrl: true } } } },
            messages: { orderBy: { createdAt: 'desc' }, take: 1 },
          },
        },
      },
      orderBy: { thread: { updatedAt: 'desc' } },
    });

    const threads = memberships.map((m) => {
      const other = m.thread.members.find((x) => x.userId !== userId)?.user ?? null;
      const last = m.thread.messages[0];
      const unreadCount = last && (!m.lastReadAt || last.createdAt > m.lastReadAt) ? 1 : 0;
      return {
        id: m.thread.id,
        other,
        lastMessage: last
          ? { id: last.id, body: last.body, senderId: last.senderId, createdAt: last.createdAt.toISOString() }
          : null,
        unreadCount,
        lastReadAt: m.lastReadAt ? m.lastReadAt.toISOString() : null,
      };
    });
    return { threads };
  }

  async listMessages(userId: string, threadId: string, dto: ListDmDto) {
    await this.assertInThread(userId, threadId);
    const limit = dto.limit ?? 40;
    const messages = await this.prisma.dmMessage.findMany({
      where: {
        threadId,
        ...(dto.before ? { createdAt: { lt: new Date(dto.before) } } : {}),
      },
      include: { sender: { select: { id: true, name: true, avatarUrl: true } } },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
    const ascending = [...messages].reverse();
    return { messages: ascending.map((m) => this.toDto(m)), hasMore: messages.length === limit };
  }

  async send(userId: string, threadId: string, dto: SendDmDto) {
    await this.assertInThread(userId, threadId);
    const message = await this.prisma.dmMessage.create({
      data: { threadId, senderId: userId, body: dto.body },
      include: { sender: { select: { id: true, name: true, avatarUrl: true } } },
    });
    await this.prisma.dmThread.update({ where: { id: threadId }, data: { updatedAt: new Date() } });
    // Un-hide for the recipient so the thread surfaces in their inbox.
    await this.prisma.dmMember.updateMany({
      where: { threadId, userId: { not: userId }, hiddenAt: { not: null } },
      data: { hiddenAt: null },
    });

    const payload = this.toDto(message);
    const members = await this.prisma.dmMember.findMany({
      where: { threadId, userId: { not: userId } },
      select: { userId: true },
    });
    for (const mem of members) {
      this.realtime.emitToUser(mem.userId, 'dm:message', payload);
      await this.notifications.create({
        userId: mem.userId,
        type: NotificationType.DM,
        title: 'New message',
        body: dto.body.length > 120 ? dto.body.slice(0, 120) + '…' : dto.body,
        data: { threadId, messageId: message.id },
      });
    }
    return payload;
  }

  async markRead(userId: string, threadId: string) {
    await this.assertInThread(userId, threadId);
    await this.prisma.dmMember.updateMany({
      where: { threadId, userId },
      data: { lastReadAt: new Date() },
    });
    return { ok: true };
  }

  /** Hide (soft-leave) a thread from the user's inbox without deleting it. */
  async hide(userId: string, threadId: string) {
    await this.assertInThread(userId, threadId);
    await this.prisma.dmMember.updateMany({
      where: { threadId, userId },
      data: { hiddenAt: new Date() },
    });
    return { ok: true };
  }

  private async assertInThread(userId: string, threadId: string) {
    const member = await this.prisma.dmMember.findFirst({ where: { threadId, userId } });
    if (!member) throw new NotFoundException('Conversation not found');
    return member;
  }

  private toDto(m: any) {
    return {
      id: m.id,
      threadId: m.threadId,
      senderId: m.senderId,
      sender: m.sender,
      body: m.body,
      createdAt: m.createdAt.toISOString(),
    };
  }
}
