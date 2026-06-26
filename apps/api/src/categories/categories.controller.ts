import { Body, Controller, Delete, Get, Param, Post, Query } from '@nestjs/common';
import { CategoriesService } from './categories.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { CreateCategoryDto } from './dto/category.dto';

@Controller('timeline/categories')
export class CategoriesController {
  constructor(private readonly categories: CategoriesService) {}

  @Get()
  list(@CurrentUser('id') userId: string, @Query('groupId') groupId?: string) {
    return this.categories.list(userId, groupId);
  }

  @Post()
  create(@CurrentUser('id') userId: string, @Body() dto: CreateCategoryDto) {
    return this.categories.create(userId, dto);
  }

  @Delete(':id')
  remove(@CurrentUser('id') userId: string, @Param('id') id: string) {
    return this.categories.remove(userId, id);
  }
}
