import { Body, Controller, Delete, Get, Param, Post, Query } from '@nestjs/common';
import { LocationService } from './location.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { PointDto, SetShareDto } from './dto/location.dto';

@Controller('groups/:groupId/location')
export class LocationController {
  constructor(private readonly location: LocationService) {}

  @Get()
  list(
    @CurrentUser('id') userId: string,
    @Param('groupId') groupId: string,
    @Query('lat') lat?: string,
    @Query('lng') lng?: string,
  ) {
    const origin = lat && lng ? { lat: Number(lat), lng: Number(lng) } : undefined;
    return this.location.listForGroup(userId, groupId, origin);
  }

  @Get('me')
  my(@CurrentUser('id') userId: string, @Param('groupId') groupId: string) {
    return this.location.myShare(userId, groupId);
  }

  @Post()
  set(@CurrentUser('id') userId: string, @Param('groupId') groupId: string, @Body() dto: SetShareDto) {
    return this.location.setShare(userId, groupId, dto);
  }

  @Post('point')
  point(@CurrentUser('id') userId: string, @Param('groupId') groupId: string, @Body() dto: PointDto) {
    return this.location.pushPoint(userId, groupId, dto);
  }

  @Delete()
  stop(@CurrentUser('id') userId: string, @Param('groupId') groupId: string) {
    return this.location.stop(userId, groupId);
  }
}
