import { Module } from '@nestjs/common';
import { MediaController } from './media.controller';
import { MediaService } from './media.service';
import { GroupsModule } from '../groups/groups.module';
import { RealtimeModule } from '../realtime/realtime.module';

@Module({
  imports: [GroupsModule, RealtimeModule],
  controllers: [MediaController],
  providers: [MediaService],
})
export class MediaModule {}
