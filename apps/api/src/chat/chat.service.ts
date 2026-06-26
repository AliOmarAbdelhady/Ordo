import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { MessageType, MemberStatus, NotificationType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { GroupsService } from '../groups/groups.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { NotificationsService } from '../notifications/notifications.service';
import { CreateMessageDto, EditMessageDto } from './dto/chat.dto';

export interface ChatMessageDto {
  id: string;
  groupId: string;
  senderId: string;
  sender: { id: string; name: string; avatarUrl: string | null };
  body: string | null;
  type: MessageType;
  replyToId: string | null;
  replyTo?: { id: string; body: string | null; senderName: string } | null;
  createdAt: string;
  editedAt: string | null;
  deleted: boolean;
  reactions: { emoji: string; count: number; userIds: string[] }[];
}

@Injectable()
export class ChatService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly groups: GroupsService,
    private readonly realtime: RealtimeGateway,
    private readonly notifications: NotificationsService,
  ) {}

  async list(userId: string, groupId: string, before?: string, limit = 40) {
    await this.groups.requireMember(groupId, userId);
    const messages = await this.prisma.message.findMany({
      where: {
        groupId,
        ...(before ? { createdAt: { lt: new Date(before) } } : {}),
      },
      include: {
        sender: { select: { id: true, name: true, avatarUrl: true } },
        reactions: { select: { userId: true, emoji: true } },
        replyTo: { include: { sender: { select: { name: true } } } },
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });

    const ascending = [...messages].reverse();
    return { messages: ascending.map((m) => this.toDto(m)), hasMore: messages.length === limit };
  }

  async send(userId: string, groupId: string, dto: CreateMessageDto): Promise<ChatMessageDto> {
    await this.groups.requirePermission(groupId, userId, 'CHAT_SEND');
    const message = await this.prisma.message.create({
      data: {
        groupId,
        senderId: userId,
        body: dto.body,
        type: MessageType.TEXT,
        replyToId: dto.replyToId ?? null,
      },
      include: {
        sender: { select: { id: true, name: true, avatarUrl: true } },
        reactions: { select: { userId: true, emoji: true } },
        replyTo: { include: { sender: { select: { name: true } } } },
      },
    });
    const payload = this.toDto(message);
    this.realtime.emitToGroup(groupId, 'chat:message', payload);
    await this.detectMentions(groupId, userId, dto.body, message.id);
    return payload;
  }

  async edit(userId: string, messageId: string, body: string): Promise<ChatMessageDto> {
    const message = await this.prisma.message.findUnique({ where: { id: messageId } });
    if (!message || message.deletedAt) throw new NotFoundException('Message not found');
    if (message.senderId !== userId) throw new ForbiddenException('You can only edit your own messages');
    const updated = await this.prisma.message.update({
      where: { id: messageId },
      data: { body, editedAt: new Date() },
      include: {
        sender: { select: { id: true, name: true, avatarUrl: true } },
        reactions: { select: { userId: true, emoji: true } },
        replyTo: { include: { sender: { select: { name: true } } } },
      },
    });
    const payload = this.toDto(updated);
    this.realtime.emitToGroup(message.groupId, 'chat:update', payload);
    return payload;
  }

  async delete(userId: string, messageId: string) {
    const message = await this.prisma.message.findUnique({ where: { id: messageId } });
    if (!message) throw new NotFoundException('Message not found');
    const isAuthor = message.senderId === userId;
    if (!isAuthor) {
      await this.groups.requirePermission(message.groupId, userId, 'CHAT_DELETE_ANY');
    }
    const updated = await this.prisma.message.update({
      where: { id: messageId },
      data: { deletedAt: new Date(), body: null },
    });
    this.realtime.emitToGroup(message.groupId, 'chat:delete', { id: messageId, groupId: message.groupId });
    return { ok: true };
  }

  async react(userId: string, messageId: string, emoji: string) {
    const message = await this.prisma.message.findUnique({ where: { id: messageId } });
    if (!message || message.deletedAt) throw new NotFoundException('Message not found');
    await this.groups.requireMember(message.groupId, userId);

    const existing = await this.prisma.messageReaction.findUnique({
      where: { messageId_userId_emoji: { messageId, userId, emoji } },
    });
    if (existing) {
      await this.prisma.messageReaction.delete({ where: { id: existing.id } });
    } else {
      await this.prisma.messageReaction.create({ data: { messageId, userId, emoji } });
    }
    // Re-fetch the full message and emit the authoritative ChatMessageDto so every
    // viewer receives a consistent reactions snapshot (avoids client/server count
    // drift). The client treats `chat:reaction` exactly like `chat:update`.
    const refreshed = await this.prisma.message.findUnique({
      where: { id: messageId },
      include: {
        sender: { select: { id: true, name: true, avatarUrl: true } },
        reactions: { select: { userId: true, emoji: true } },
        replyTo: { include: { sender: { select: { name: true } } } },
      },
    });
    if (refreshed) this.realtime.emitToGroup(message.groupId, 'chat:reaction', this.toDto(refreshed));
    return { ok: true };
  }

  async markRead(userId: string, groupId: string) {
    await this.groups.markRead(userId, groupId);
    return { ok: true };
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  private async detectMentions(groupId: string, senderId: string, body: string, messageId: string) {
    const matches = body.match(/@([a-z0-9_]+)/gi) ?? [];
    const usernames = [...new Set(matches.map((m) => m.slice(1).toLowerCase()))];
    if (!usernames.length) return;

    const members = await this.prisma.groupMember.findMany({
      where: { groupId, status: MemberStatus.ACTIVE, user: { username: { in: usernames } } },
      select: { userId: true },
    });
    for (const m of members) {
      if (m.userId === senderId) continue;
      // Route through NotificationsService so the DB row AND the emitted socket
      // event share the canonical shape ({id,type,title,body,data,createdAt}) —
      // the bespoke emit below previously omitted id/createdAt and crashed the
      // mobile OrdoNotification.fromJson parser.
      await this.notifications.create({
        userId: m.userId,
        type: NotificationType.MESSAGE_MENTION,
        title: 'You were mentioned',
        body: body.length > 120 ? body.slice(0, 120) + '…' : body,
        data: { groupId, messageId },
      });
    }
  }

  private toDto(m: any): ChatMessageDto {
    const reactionMap = new Map<string, string[]>();
    for (const r of m.reactions ?? []) {
      const arr = reactionMap.get(r.emoji) ?? [];
      arr.push(r.userId);
      reactionMap.set(r.emoji, arr);
    }
    return {
      id: m.id,
      groupId: m.groupId,
      senderId: m.senderId,
      sender: m.sender,
      body: m.body,
      type: m.type,
      replyToId: m.replyToId ?? null,
      replyTo: m.replyTo
        ? { id: m.replyTo.id, body: m.replyTo.body, senderName: m.replyTo.sender?.name ?? 'Unknown' }
        : null,
      createdAt: m.createdAt.toISOString(),
      editedAt: m.editedAt ? m.editedAt.toISOString() : null,
      deleted: !!m.deletedAt,
      reactions: [...reactionMap.entries()].map(([emoji, userIds]) => ({ emoji, count: userIds.length, userIds })),
    };
  }
}
