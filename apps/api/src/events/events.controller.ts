import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { EventsService } from './events.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { RsvpDto } from './dto/event.dto';

@Controller('events')
export class EventsController {
  constructor(private readonly events: EventsService) {}

  @Post(':blockId/rsvp')
  rsvp(
    @CurrentUser('id') userId: string,
    @Param('blockId') blockId: string,
    @Body() dto: RsvpDto,
  ) {
    return this.events.rsvp(userId, blockId, dto);
  }

  @Get(':blockId/attendees')
  attendees(@CurrentUser('id') userId: string, @Param('blockId') blockId: string) {
    return this.events.attendees(userId, blockId);
  }
}
