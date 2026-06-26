import { Body, Controller, Delete, Get, Param, Patch, Post } from '@nestjs/common';
import { AnnouncementsService } from './announcements.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { CreateAnnouncementDto, UpdateAnnouncementDto } from './dto/announcement.dto';

@Controller()
export class AnnouncementsController {
  constructor(private readonly announcements: AnnouncementsService) {}

  @Get('groups/:groupId/announcements')
  list(@CurrentUser('id') userId: string, @Param('groupId') groupId: string) {
    return this.announcements.list(userId, groupId);
  }

  @Post('groups/:groupId/announcements')
  create(
    @CurrentUser('id') userId: string,
    @Param('groupId') groupId: string,
    @Body() dto: CreateAnnouncementDto,
  ) {
    return this.announcements.create(userId, groupId, dto);
  }

  @Patch('announcements/:id')
  update(
    @CurrentUser('id') userId: string,
    @Param('id') id: string,
    @Body() dto: UpdateAnnouncementDto,
  ) {
    return this.announcements.update(userId, id, dto);
  }

  @Delete('announcements/:id')
  remove(@CurrentUser('id') userId: string, @Param('id') id: string) {
    return this.announcements.remove(userId, id);
  }
}
