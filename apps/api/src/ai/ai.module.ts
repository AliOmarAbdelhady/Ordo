import { Module } from '@nestjs/common';
import { AiController } from './ai.controller';
import { AiService } from './ai.service';
import { GroupsModule } from '../groups/groups.module';
import { TimelineModule } from '../timeline/timeline.module';
import { TasksModule } from '../tasks/tasks.module';
import { TodosModule } from '../todos/todos.module';

@Module({
  imports: [GroupsModule, TimelineModule, TasksModule, TodosModule],
  controllers: [AiController],
  providers: [AiService],
})
export class AiModule {}
