import { Body, Controller, Delete, Get, Param, Patch, Post, Query } from '@nestjs/common';
import { ChatService } from './chat.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { CreateMessageDto, EditMessageDto, ReactDto, ListMessagesDto } from './dto/chat.dto';

@Controller()
export class ChatController {
  constructor(private readonly chat: ChatService) {}

  @Get('groups/:groupId/messages')
  list(
    @CurrentUser('id') userId: string,
    @Param('groupId') groupId: string,
    @Query() q: ListMessagesDto,
  ) {
    return this.chat.list(userId, groupId, q.before, q.limit ?? 40);
  }

  @Post('groups/:groupId/messages')
  send(
    @CurrentUser('id') userId: string,
    @Param('groupId') groupId: string,
    @Body() dto: CreateMessageDto,
  ) {
    return this.chat.send(userId, groupId, dto);
  }

  @Post('groups/:groupId/read')
  markRead(@CurrentUser('id') userId: string, @Param('groupId') groupId: string) {
    return this.chat.markRead(userId, groupId);
  }

  @Patch('messages/:messageId')
  edit(
    @CurrentUser('id') userId: string,
    @Param('messageId') messageId: string,
    @Body() dto: EditMessageDto,
  ) {
    return this.chat.edit(userId, messageId, dto.body);
  }

  @Delete('messages/:messageId')
  remove(@CurrentUser('id') userId: string, @Param('messageId') messageId: string) {
    return this.chat.delete(userId, messageId);
  }

  @Post('messages/:messageId/reactions')
  react(
    @CurrentUser('id') userId: string,
    @Param('messageId') messageId: string,
    @Body() dto: ReactDto,
  ) {
    return this.chat.react(userId, messageId, dto.emoji);
  }
}
