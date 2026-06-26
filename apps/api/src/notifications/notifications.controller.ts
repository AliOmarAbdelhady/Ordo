import { Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { NotificationsService } from './notifications.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Get()
  list(@CurrentUser('id') userId: string, @Query('unreadOnly') unreadOnly?: string) {
    return this.notifications.list(userId, unreadOnly === 'true');
  }

  @Get('unread-count')
  count(@CurrentUser('id') userId: string) {
    return this.notifications.unreadCount(userId);
  }

  @Post('read')
  read(@CurrentUser('id') userId: string, @Body() body: { id?: string }) {
    return this.notifications.markRead(userId, body.id);
  }
}
