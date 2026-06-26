import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { LocationMode } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { GroupsService } from '../groups/groups.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { haversineMeters, LatLng } from '../common/utils/geo';
import { PointDto, SetShareDto } from './dto/location.dto';

// ~440m radius. APPROXIMATE mode scatters each point uniformly within this disc
// using a FRESH random offset per push (direction + magnitude), so an observer
// cannot de-fuzz by subtracting a known constant the way the old fixed +0.005°
// bias allowed.
const APPROX_RADIUS_DEG = 0.004;

@Injectable()
export class LocationService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly groups: GroupsService,
    private readonly realtime: RealtimeGateway,
  ) {}

  async setShare(userId: string, groupId: string, dto: SetShareDto) {
    await this.groups.requirePermission(groupId, userId, 'LOCATION_SHARE');

    // PRECISE_TEMPORARY is meant to be short-lived. If the client omits an expiry
    // (or sends one in the past), default to 1 hour so precise sharing always
    // stops on its own instead of broadcasting indefinitely.
    let expiresAt: Date | null = dto.expiresAt ? new Date(dto.expiresAt) : null;
    if (dto.mode === LocationMode.PRECISE_TEMPORARY && (!expiresAt || expiresAt <= new Date())) {
      expiresAt = new Date(Date.now() + 60 * 60 * 1000);
    }

    const share = await this.prisma.locationShare.upsert({
      where: { userId_groupId: { userId, groupId } },
      update: { mode: dto.mode, expiresAt },
      create: { userId, groupId, mode: dto.mode, expiresAt },
    });
    return this.toShareDto(share);
  }

  async stop(userId: string, groupId: string) {
    await this.groups.requireMember(groupId, userId);
    await this.prisma.locationShare.updateMany({
      where: { userId, groupId },
      data: { mode: LocationMode.OFF, expiresAt: null },
    });
    this.realtime.emitToGroup(groupId, 'location:updated', { userId, groupId, mode: 'OFF' });
    return { ok: true };
  }

  async pushPoint(userId: string, groupId: string, dto: PointDto) {
    await this.groups.requirePermission(groupId, userId, 'LOCATION_SHARE');
    const share = await this.prisma.locationShare.findUnique({
      where: { userId_groupId: { userId, groupId } },
    });
    if (!share || share.mode === LocationMode.OFF) {
      throw new BadRequestException('Location sharing is off for this group');
    }
    if (share.expiresAt && share.expiresAt < new Date()) {
      throw new BadRequestException('Your location share has expired');
    }
    if (Math.abs(dto.lat) > 90 || Math.abs(dto.lng) > 180) {
      throw new BadRequestException('Invalid coordinates');
    }

    // Approximate mode fuzzes the point so it is not precise. Each push gets a
    // fresh random offset (uniform within APPROX_RADIUS_DEG) — never a constant.
    let lat = dto.lat;
    let lng = dto.lng;
    if (share.mode === LocationMode.APPROXIMATE) {
      const angle = Math.random() * 2 * Math.PI;
      const r = APPROX_RADIUS_DEG * Math.sqrt(Math.random()); // uniform over the disc
      lat = dto.lat + Math.cos(angle) * r;
      lng = dto.lng + Math.sin(angle) * r;
    }

    const point = await this.prisma.locationPoint.create({
      data: { shareId: share.id, lat, lng, accuracy: dto.accuracy, heading: dto.heading },
    });

    this.realtime.emitToGroup(groupId, 'location:updated', {
      userId,
      groupId,
      mode: share.mode,
      lat,
      lng,
      accuracy: dto.accuracy ?? null,
      at: point.createdAt.toISOString(),
    });
    return { ok: true };
  }

  /** Active shares for a group with each member's latest point. */
  async listForGroup(userId: string, groupId: string, origin?: LatLng) {
    await this.groups.requireMember(groupId, userId);
    const shares = await this.prisma.locationShare.findMany({
      where: { groupId, mode: { not: LocationMode.OFF } },
      include: { user: { select: { id: true, name: true, avatarUrl: true } } },
    });

    const now = new Date();
    const out: any[] = [];
    for (const s of shares) {
      if (s.expiresAt && s.expiresAt < now) continue;
      const latest = await this.prisma.locationPoint.findFirst({
        where: { shareId: s.id },
        orderBy: { createdAt: 'desc' },
      });
      const point = latest
        ? {
            lat: latest.lat,
            lng: latest.lng,
            accuracy: latest.accuracy,
            heading: latest.heading,
            at: latest.createdAt.toISOString(),
            distanceMeters: origin ? haversineMeters(origin, { lat: latest.lat, lng: latest.lng }) : null,
          }
        : null;
      out.push({
        userId: s.userId,
        user: s.user,
        mode: s.mode,
        expiresAt: s.expiresAt ? s.expiresAt.toISOString() : null,
        point,
        isOwn: s.userId === userId,
      });
    }
    return { locations: out };
  }

  async myShare(userId: string, groupId: string) {
    await this.groups.requireMember(groupId, userId);
    const share = await this.prisma.locationShare.findUnique({
      where: { userId_groupId: { userId, groupId } },
    });
    return { share: share ? this.toShareDto(share) : null };
  }

  private toShareDto(s: any) {
    return {
      userId: s.userId,
      groupId: s.groupId,
      mode: s.mode,
      expiresAt: s.expiresAt ? new Date(s.expiresAt).toISOString() : null,
    };
  }
}
