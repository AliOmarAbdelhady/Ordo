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
}
