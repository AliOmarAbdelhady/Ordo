import { Injectable, NotFoundException } from '@nestjs/common';
import { NotificationType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { GroupsService } from '../groups/groups.service';
import { NotificationsService } from '../notifications/notifications.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { CreateAnnouncementDto, UpdateAnnouncementDto } from './dto/announcement.dto';

@Injectable()
export class AnnouncementsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly groups: GroupsService,
    private readonly notifications: NotificationsService,
    private readonly realtime: RealtimeGateway,
  ) {}

  async list(userId: string, groupId: string) {
    await this.groups.requireMember(groupId, userId);
    const items = await this.prisma.announcement.findMany({
      where: { groupId },
      orderBy: [{ pinned: 'desc' }, { createdAt: 'desc' }],
      take: 50,
      include: { createdBy: { select: { id: true, name: true, avatarUrl: true } } },
    });
    return { announcements: items.map((a) => this.toDto(a)) };
  }

  async create(userId: string, groupId: string, dto: CreateAnnouncementDto) {
    await this.groups.requirePermission(groupId, userId, 'ANNOUNCEMENT_CREATE');
    const created = await this.prisma.announcement.create({
      data: {
        groupId,
        createdById: userId,
        title: dto.title,
        body: dto.body,
        pinned: dto.pinned ?? false,
      },
      include: { createdBy: { select: { id: true, name: true, avatarUrl: true } } },
    });

    // Notify every active member (the creator included — harmless and cheap at MVP scale).
    const members = await this.prisma.groupMember.findMany({
      where: { groupId, status: 'ACTIVE' },
      select: { userId: true },
    });
    await this.notifications.createMany(
      members.map((m) => ({
        userId: m.userId,
        type: NotificationType.ANNOUNCEMENT,
        title: `📣 ${dto.title}`,
        body: dto.body.length > 120 ? dto.body.slice(0, 120) + '…' : dto.body,
        data: { groupId, announcementId: created.id },
      })),
    );
    this.realtime.emitToGroup(groupId, 'announcement:created', this.toDto(created));
    return this.toDto(created);
  }

  async update(userId: string, id: string, dto: UpdateAnnouncementDto) {
    const ann = await this.assertManageable(userId, id);
    const updated = await this.prisma.announcement.update({
      where: { id },
      data: { pinned: dto.pinned },
      include: { createdBy: { select: { id: true, name: true, avatarUrl: true } } },
    });
    this.realtime.emitToGroup(ann.groupId, 'announcement:updated', this.toDto(updated));
    return this.toDto(updated);
  }

  async remove(userId: string, id: string) {
    const ann = await this.assertManageable(userId, id);
    await this.prisma.announcement.delete({ where: { id } });
    this.realtime.emitToGroup(ann.groupId, 'announcement:deleted', { id });
    return { ok: true };
  }

  private async assertManageable(userId: string, id: string) {
    const ann = await this.prisma.announcement.findUnique({ where: { id } });
    if (!ann) throw new NotFoundException('Announcement not found');
    if (ann.createdById === userId) return ann;
    await this.groups.requirePermission(ann.groupId, userId, 'ANNOUNCEMENT_DELETE_ANY');
    return ann;
  }

  private toDto(a: any) {
    return {
      id: a.id,
      groupId: a.groupId,
      title: a.title,
      body: a.body,
      pinned: a.pinned,
      createdBy: a.createdBy ?? { id: a.createdById },
      createdAt: new Date(a.createdAt).toISOString(),
    };
  }
}
