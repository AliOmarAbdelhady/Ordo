import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import { AiService } from './ai.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { ApplySuggestionDto, ExtractTasksDto, ParseCommandDto } from './dto/ai.dto';

@Controller('ai')
export class AiController {
  constructor(private readonly ai: AiService) {}

  @Post('parse-command')
  parse(@CurrentUser('id') userId: string, @Body() dto: ParseCommandDto) {
    return this.ai.parseCommand(userId, dto);
  }

  @Post('extract-tasks')
  extract(@CurrentUser('id') userId: string, @Body() dto: ExtractTasksDto) {
    return this.ai.extractTasks(userId, dto);
  }

  @Post('summarize-group')
  summarize(@CurrentUser('id') userId: string, @Body() body: { groupId: string }) {
    return this.ai.summarizeGroup(userId, body.groupId);
  }

  @Get('plan-day')
  planDay(@CurrentUser('id') userId: string, @Query('timezone') timezone?: string) {
    return this.ai.planDay(userId, timezone);
  }

  @Post('apply-suggestion')
  apply(@CurrentUser('id') userId: string, @Body() dto: ApplySuggestionDto) {
    return this.ai.apply(userId, dto);
  }
}
