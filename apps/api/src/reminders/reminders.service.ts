import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { NotificationType, ReminderStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

const TICK_MS = 30_000;

@Injectable()
export class RemindersService implements OnModuleInit {
  private readonly logger = new Logger('Reminders');
  private timer?: NodeJS.Timeout;

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  onModuleInit() {
    // Light in-process scheduler. For multi-instance production, move this to
    // BullMQ delayed jobs (see CLAUDE.md).
    this.timer = setInterval(() => this.tick().catch((e) => this.logger.error(e)), TICK_MS);
    this.logger.log('Reminder scheduler started');
    // Fire once shortly after boot.
    setTimeout(() => this.tick().catch((e) => this.logger.error(e)), 5_000);
  }

  async tick() {
    const now = new Date();
    const due = await this.prisma.reminder.findMany({
      where: { status: ReminderStatus.SCHEDULED, remindAt: { lte: now } },
      take: 100,
    });
    if (!due.length) return;

    for (const reminder of due) {
      const type: NotificationType =
        reminder.refType === 'TIMELINE_BLOCK' ? 'EVENT_SOON' : 'REMINDER';
      await this.notifications.create({
        userId: reminder.userId,
        type,
        title: reminder.title,
        body: reminder.body ?? undefined,
        data: { refType: reminder.refType, refId: reminder.refId, reminderId: reminder.id },
      });
      await this.prisma.reminder.update({
        where: { id: reminder.id },
        data: { status: ReminderStatus.SENT },
      });
    }
    this.logger.log(`Dispatched ${due.length} reminder(s)`);
  }
}
