import { BadRequestException, Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { AvailabilityService } from './availability.service';
import { FindSlotsDto, GroupAvailabilityStripDto } from './dto/availability.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';

const DAY = 24 * 60 * 60 * 1000;

@Controller('availability')
export class AvailabilityController {
  constructor(private readonly availability: AvailabilityService) {}

  @Post('find-slots')
  find(@CurrentUser('id') userId: string, @Body() dto: FindSlotsDto) {
    return this.availability.findSlots(userId, dto);
  }

  @Get('groups/:groupId')
  strip(
    @CurrentUser('id') userId: string,
    @Param('groupId') groupId: string,
    @Query() q: GroupAvailabilityStripDto,
  ) {
    const now = Date.now();
    const from = q.from ? new Date(q.from) : new Date(now);
    const to = q.to ? new Date(q.to) : new Date(now + DAY);
    if (!(from < to)) throw new BadRequestException('from must be before to');
    if (to.getTime() - from.getTime() > 31 * DAY) {
      throw new BadRequestException('Range cannot exceed 31 days');
    }
    return this.availability.groupAvailabilityStrip(userId, groupId, from, to);
  }
}
