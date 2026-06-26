import { Body, Controller, Delete, Get, Param, Patch, Post, Query } from '@nestjs/common';
import { TasksService, TaskTab } from './tasks.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { CreateTaskDto, UpdateTaskDto, CreateCommentDto } from './dto/task.dto';

@Controller('tasks')
export class TasksController {
  constructor(private readonly tasks: TasksService) {}

  @Post()
  create(@CurrentUser('id') userId: string, @Body() dto: CreateTaskDto) {
    return this.tasks.create(userId, dto);
  }

  @Get()
  list(
    @CurrentUser('id') userId: string,
    @Query('groupId') groupId: string,
    @Query('tab') tab: TaskTab = 'all',
  ) {
    return this.tasks.list(userId, groupId, tab);
  }

  /** Cross-group "mine" view for the unified dashboard (tasks assigned to me, all groups). */
  @Get('mine')
  listMine(@CurrentUser('id') userId: string) {
    return this.tasks.listMine(userId);
  }

  @Get(':id')
  getOne(@CurrentUser('id') userId: string, @Param('id') id: string) {
    return this.tasks.getOne(userId, id);
  }

  @Patch(':id')
  update(@CurrentUser('id') userId: string, @Param('id') id: string, @Body() dto: UpdateTaskDto) {
    return this.tasks.update(userId, id, dto);
  }

  @Delete(':id')
  remove(@CurrentUser('id') userId: string, @Param('id') id: string) {
    return this.tasks.remove(userId, id);
  }

  @Post(':id/comments')
  comment(
    @CurrentUser('id') userId: string,
    @Param('id') id: string,
    @Body() dto: CreateCommentDto,
  ) {
    return this.tasks.addComment(userId, id, dto.body);
  }
}
