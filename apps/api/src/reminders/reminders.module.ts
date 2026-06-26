import { Module } from '@nestjs/common';
import { RemindersService } from './reminders.service';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [NotificationsModule],
  providers: [RemindersService],
})
export class RemindersModule {}
