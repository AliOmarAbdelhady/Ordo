import { Controller, Get, Query } from '@nestjs/common';
import { SearchService } from './search.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { SearchQueryDto } from './dto/search.dto';

@Controller('search')
export class SearchController {
  constructor(private readonly search: SearchService) {}

  @Get()
  query(@CurrentUser('id') userId: string, @Query() dto: SearchQueryDto) {
    return this.search.search(userId, (dto.q ?? '').trim());
  }
}
