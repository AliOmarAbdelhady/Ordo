import { Module } from '@nestjs/common';
import { LocationController } from './location.controller';
import { LocationService } from './location.service';
import { GroupsModule } from '../groups/groups.module';
import { RealtimeModule } from '../realtime/realtime.module';

@Module({
  imports: [GroupsModule, RealtimeModule],
  controllers: [LocationController],
  providers: [LocationService],
})
export class LocationModule {}
