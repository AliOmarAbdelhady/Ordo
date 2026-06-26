import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { GroupsService } from '../groups/groups.service';
import { NotificationsService } from '../notifications/notifications.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { tallyPoll } from '../common/utils/poll-tally';
import { NotificationType } from '@prisma/client';
import { CreatePollDto, VoteDto } from './dto/poll.dto';

@Injectable()
export class PollsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly groups: GroupsService,
    private readonly notifications: NotificationsService,
    private readonly realtime: RealtimeGateway,
  ) {}

  async create(userId: string, groupId: string, dto: CreatePollDto) {
    await this.groups.requirePermission(groupId, userId, 'POLL_CREATE');
    const poll = await this.prisma.poll.create({
      data: {
        groupId,
        createdById: userId,
        question: dto.question,
        multiple: dto.multiple ?? false,
        closesAt: dto.closesAt ? new Date(dto.closesAt) : null,
        options: {
          create: dto.options.map((o, i) => ({ text: o.text, order: i })),
        },
      },
      include: { options: { orderBy: { order: 'asc' } } },
    });

    this.realtime.emitToGroup(groupId, 'poll:created', { groupId, pollId: poll.id });
    return this.toDto(poll, [], userId);
  }

  async list(userId: string, groupId: string) {
    await this.groups.requireMember(groupId, userId);
    const polls = await this.prisma.poll.findMany({
      where: { groupId },
      include: { options: { orderBy: { order: 'asc' } }, votes: true },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
    return { polls: polls.map((p) => this.toDto(p, p.votes, userId)) };
  }

  async get(userId: string, pollId: string) {
    const poll = await this.prisma.poll.findUnique({
      where: { id: pollId },
      include: { options: { orderBy: { order: 'asc' } }, votes: true },
    });
    if (!poll) throw new NotFoundException('Poll not found');
    await this.groups.requireMember(poll.groupId, userId);
    return this.toDto(poll, poll.votes, userId);
  }

  async vote(userId: string, pollId: string, dto: VoteDto) {
    const poll = await this.prisma.poll.findUnique({
      where: { id: pollId },
      include: { options: true },
    });
    if (!poll) throw new NotFoundException('Poll not found');
    await this.groups.requireMember(poll.groupId, userId);
    if (poll.closed || (poll.closesAt && poll.closesAt < new Date())) {
      throw new BadRequestException('This poll is closed');
    }
    const validIds = new Set(poll.options.map((o) => o.id));
    for (const id of dto.optionIds) {
      if (!validIds.has(id)) throw new BadRequestException('Invalid option');
    }
    if (!poll.multiple && dto.optionIds.length > 1) {
      throw new BadRequestException('This poll allows a single choice only');
    }

    // Replace the voter's previous choices atomically.
    await this.prisma.$transaction([
      this.prisma.pollVote.deleteMany({ where: { pollId, userId } }),
      this.prisma.pollVote.createMany({
        data: dto.optionIds.map((optionId) => ({ pollId, optionId, userId })),
      }),
    ]);

    const refreshed = await this.prisma.poll.findUnique({
      where: { id: pollId },
      include: { options: { orderBy: { order: 'asc' } }, votes: true },
    });
    const result = this.toDto(refreshed!, refreshed!.votes, userId);
    this.realtime.emitToGroup(poll.groupId, 'poll:updated', result);
    return result;
  }

  async close(userId: string, pollId: string) {
    const poll = await this.prisma.poll.findUnique({ where: { id: pollId } });
    if (!poll) throw new NotFoundException('Poll not found');
    // Always require ACTIVE membership first, even for the creator — a user who
    // created a poll and later left/was removed must not be able to act on it.
    await this.groups.requireMember(poll.groupId, userId);
    const isCreator = poll.createdById === userId;
    if (!isCreator) {
      await this.groups.requirePermission(poll.groupId, userId, 'POLL_CLOSE_ANY');
    }
    const updated = await this.prisma.poll.update({
      where: { id: pollId },
      data: { closed: true },
    });
    this.realtime.emitToGroup(poll.groupId, 'poll:updated', { id: pollId, closed: true });
    return { ok: true, closed: updated.closed };
  }

  async remove(userId: string, pollId: string) {
    const poll = await this.prisma.poll.findUnique({ where: { id: pollId } });
    if (!poll) throw new NotFoundException('Poll not found');
    await this.groups.requireMember(poll.groupId, userId);
    const isCreator = poll.createdById === userId;
    if (!isCreator) {
      await this.groups.requirePermission(poll.groupId, userId, 'POLL_CLOSE_ANY');
    }
    await this.prisma.poll.delete({ where: { id: pollId } });
    this.realtime.emitToGroup(poll.groupId, 'poll:deleted', { id: pollId });
    return { ok: true };
  }

  private toDto(poll: any, votes: any[], viewerId: string) {
    const tally = tallyPoll(
      poll.options.map((o: any) => ({ id: o.id, text: o.text })),
      votes.map((v: any) => ({ optionId: v.optionId, userId: v.userId })),
      viewerId,
    );
    return {
      id: poll.id,
      groupId: poll.groupId,
      question: poll.question,
      multiple: poll.multiple,
      closed: poll.closed || (poll.closesAt ? new Date(poll.closesAt) < new Date() : false),
      closesAt: poll.closesAt ? new Date(poll.closesAt).toISOString() : null,
      createdBy: poll.createdById,
      createdAt: new Date(poll.createdAt).toISOString(),
      results: tally,
    };
  }
}
