import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { NotificationType, ReminderStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

const TICK_MS = 30_000;

@Injectable()
export class RemindersService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger('Reminders');
  private timer?: NodeJS.Timeout;
  private bootTimer?: NodeJS.Timeout;

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  onModuleInit() {
    // Light in-process scheduler. For multi-instance production, move this to
    // BullMQ delayed jobs (see CLAUDE.md).
    this.timer = setInterval(() => this.tick().catch((e) => this.logger.error(e)), TICK_MS);
    // Fire once shortly after boot.
    this.bootTimer = setTimeout(() => this.tick().catch((e) => this.logger.error(e)), 5_000);
    this.logger.log('Reminder scheduler started');
  }

  onModuleDestroy() {
    // Clear timers so hot-reload / shutdown does not stack duplicate tickers.
    if (this.timer) clearInterval(this.timer);
    if (this.bootTimer) clearTimeout(this.bootTimer);
  }

  async tick() {
    const now = new Date();
    const due = await this.prisma.reminder.findMany({
      where: { status: ReminderStatus.SCHEDULED, remindAt: { lte: now } },
      take: 100,
    });
    if (!due.length) return;

    let dispatched = 0;
    for (const reminder of due) {
      // Each reminder is dispatched independently so a single failure (transient
      // DB error, etc.) cannot abort the rest of the batch.
      try {
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
        dispatched++;
      } catch (e) {
        this.logger.error(`Failed to dispatch reminder ${reminder.id}: ${(e as Error).message}`);
        // Mark FAILED so a reminder that errors persistently is not retried every
        // tick (which would spin forever). A transient one-shot failure is lost,
        // which is preferable to an infinite retry loop.
        try {
          await this.prisma.reminder.update({
            where: { id: reminder.id },
            data: { status: ReminderStatus.FAILED },
          });
        } catch {
          // ignore — best-effort
        }
      }
    }
    this.logger.log(`Dispatched ${dispatched}/${due.length} reminder(s)`);
  }
}
