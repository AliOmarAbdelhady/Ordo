import { Body, Controller, Delete, Get, Param, Post } from '@nestjs/common';
import { PollsService } from './polls.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { CreatePollDto, VoteDto } from './dto/poll.dto';

@Controller()
export class PollsController {
  constructor(private readonly polls: PollsService) {}

  @Get('groups/:groupId/polls')
  list(@CurrentUser('id') userId: string, @Param('groupId') groupId: string) {
    return this.polls.list(userId, groupId);
  }

  @Post('groups/:groupId/polls')
  create(
    @CurrentUser('id') userId: string,
    @Param('groupId') groupId: string,
    @Body() dto: CreatePollDto,
  ) {
    return this.polls.create(userId, groupId, dto);
  }

  @Get('polls/:pollId')
  get(@CurrentUser('id') userId: string, @Param('pollId') pollId: string) {
    return this.polls.get(userId, pollId);
  }

  @Post('polls/:pollId/vote')
  vote(
    @CurrentUser('id') userId: string,
    @Param('pollId') pollId: string,
    @Body() dto: VoteDto,
  ) {
    return this.polls.vote(userId, pollId, dto);
  }

  @Post('polls/:pollId/close')
  close(@CurrentUser('id') userId: string, @Param('pollId') pollId: string) {
    return this.polls.close(userId, pollId);
  }

  @Delete('polls/:pollId')
  remove(@CurrentUser('id') userId: string, @Param('pollId') pollId: string) {
    return this.polls.remove(userId, pollId);
  }
}
