import { Module } from '@nestjs/common';
import { ChatController } from './chat.controller';
import { ChatService } from './chat.service';
import { GroupsModule } from '../groups/groups.module';
import { RealtimeModule } from '../realtime/realtime.module';

@Module({
  imports: [GroupsModule, RealtimeModule],
  controllers: [ChatController],
  providers: [ChatService],
})
export class ChatModule {}
