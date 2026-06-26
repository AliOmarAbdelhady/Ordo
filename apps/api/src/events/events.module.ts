import { Module } from '@nestjs/common';
import { EventsController } from './events.controller';
import { EventsService } from './events.service';
import { GroupsModule } from '../groups/groups.module';
import { RealtimeModule } from '../realtime/realtime.module';

@Module({
  imports: [GroupsModule, RealtimeModule],
  controllers: [EventsController],
  providers: [EventsService],
})
export class EventsModule {}
