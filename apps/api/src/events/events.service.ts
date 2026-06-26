import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { GroupsService } from '../groups/groups.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { RsvpDto } from './dto/event.dto';

@Injectable()
export class EventsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly groups: GroupsService,
    private readonly realtime: RealtimeGateway,
  ) {}

  /** RSVPs are only meaningful for group events; the viewer must be a member. */
  private async assertGroupEvent(userId: string, blockId: string) {
    const block = await this.prisma.timelineBlock.findUnique({ where: { id: blockId } });
    // Only blocks explicitly created as events are RSVP-able — previously any
    // ordinary group timeline block could be RSVP'd.
    if (!block || block.deletedAt || !block.groupId || !block.isEvent) {
      throw new NotFoundException('Event not found');
    }
    await this.groups.requireMember(block.groupId, userId);
    return block;
  }

  async rsvp(userId: string, blockId: string, dto: RsvpDto) {
    const block = await this.assertGroupEvent(userId, blockId);
    await this.prisma.eventAttendee.upsert({
      where: { blockId_userId: { blockId, userId } },
      update: { status: dto.status },
      create: { blockId, userId, status: dto.status },
    });
    this.realtime.emitToGroup(block.groupId!, 'event:rsvp', { blockId, userId, status: dto.status });
    return this.results(blockId);
  }

  async results(blockId: string) {
    const attendees = await this.prisma.eventAttendee.findMany({
      where: { blockId },
      include: { user: { select: { id: true, name: true, avatarUrl: true } } },
    });
    const by = (status: string) => attendees.filter((a) => a.status === status).map((a) => a.user);
    return {
      blockId,
      going: by('GOING'),
      maybe: by('MAYBE'),
      notGoing: by('NOT_GOING'),
      counts: {
        going: by('GOING').length,
        maybe: by('MAYBE').length,
        notGoing: by('NOT_GOING').length,
      },
    };
  }

  async attendees(userId: string, blockId: string) {
    await this.assertGroupEvent(userId, blockId);
    return this.results(blockId);
  }
}
