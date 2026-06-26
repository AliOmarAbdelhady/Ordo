import { Body, Controller, Delete, Get, Param, Post, Query } from '@nestjs/common';
import { InboxService } from './inbox.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { CreateThreadDto, ListDmDto, SendDmDto } from './dto/inbox.dto';

@Controller('inbox')
export class InboxController {
  constructor(private readonly inbox: InboxService) {}

  @Get('threads')
  threads(@CurrentUser('id') userId: string) {
    return this.inbox.listThreads(userId);
  }

  @Post('threads')
  createThread(@CurrentUser('id') userId: string, @Body() dto: CreateThreadDto) {
    return this.inbox.findOrCreateThread(userId, dto);
  }

  @Get('threads/:id/messages')
  messages(
    @CurrentUser('id') userId: string,
    @Param('id') id: string,
    @Query() dto: ListDmDto,
  ) {
    return this.inbox.listMessages(userId, id, dto);
  }

  @Post('threads/:id/messages')
  send(
    @CurrentUser('id') userId: string,
    @Param('id') id: string,
    @Body() dto: SendDmDto,
  ) {
    return this.inbox.send(userId, id, dto);
  }

  @Post('threads/:id/read')
  markRead(@CurrentUser('id') userId: string, @Param('id') id: string) {
    return this.inbox.markRead(userId, id);
  }

  @Delete('threads/:id')
  hide(@CurrentUser('id') userId: string, @Param('id') id: string) {
    return this.inbox.hide(userId, id);
  }
}
