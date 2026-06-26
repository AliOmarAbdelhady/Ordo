import { Body, Controller, Delete, Get, Param, Patch, Post, Query } from '@nestjs/common';
import { TodosService, TodoTab } from './todos.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { CreateTodoDto, UpdateTodoDto, ReorderDto } from './dto/todo.dto';

@Controller('todos')
export class TodosController {
  constructor(private readonly todos: TodosService) {}

  @Post()
  create(@CurrentUser('id') userId: string, @Body() dto: CreateTodoDto) {
    return this.todos.create(userId, dto);
  }

  @Get()
  list(
    @CurrentUser('id') userId: string,
    @Query('groupId') groupId: string | null,
    @Query('tab') tab: TodoTab = 'today',
  ) {
    return this.todos.list(userId, groupId ?? null, tab);
  }

  /** Cross-group "mine" view for the unified dashboard (personal + all groups). */
  @Get('mine')
  listMine(@CurrentUser('id') userId: string, @Query('tab') tab: TodoTab = 'today') {
    return this.todos.listMine(userId, tab);
  }

  @Patch('reorder')
  reorder(@CurrentUser('id') userId: string, @Body() dto: ReorderDto) {
    return this.todos.reorder(userId, dto.ids);
  }

  @Patch(':id')
  update(@CurrentUser('id') userId: string, @Param('id') id: string, @Body() dto: UpdateTodoDto) {
    return this.todos.update(userId, id, dto);
  }

  @Delete(':id')
  remove(@CurrentUser('id') userId: string, @Param('id') id: string) {
    return this.todos.remove(userId, id);
  }
}
