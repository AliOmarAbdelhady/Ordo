import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { TimelineService } from './timeline.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { CreateBlockDto, UpdateBlockDto, SyncBlocksDto } from './dto/timeline.dto';

function range(query: { from?: string; to?: string }) {
  const now = Date.now();
  const from = query.from ? new Date(query.from) : new Date(now - 24 * 60 * 60 * 1000);
  const to = query.to ? new Date(query.to) : new Date(now + 7 * 24 * 60 * 60 * 1000);
  return { from, to };
}

@Controller()
export class TimelineController {
  constructor(private readonly timeline: TimelineService) {}

  // ── Self timeline ──────────────────────────────────────────────────────────
  @Get('timeline/me')
  self(@CurrentUser('id') userId: string, @Query() q: { from?: string; to?: string }) {
    const { from, to } = range(q);
    return this.timeline.listSelf(userId, from, to);
  }

  // ── Group timeline ─────────────────────────────────────────────────────────
  @Get('timeline/group/:groupId')
  group(
    @CurrentUser('id') userId: string,
    @Param('groupId') groupId: string,
    @Query() q: { from?: string; to?: string },
  ) {
    const { from, to } = range(q);
    return this.timeline.listGroup(userId, groupId, from, to);
  }

  // ── Block CRUD ─────────────────────────────────────────────────────────────
  @Post('timeline/blocks')
  create(@CurrentUser('id') userId: string, @Body() dto: CreateBlockDto) {
    return this.timeline.create(userId, dto);
  }

  @Get('timeline/blocks/:id')
  getOne(@CurrentUser('id') userId: string, @Param('id') id: string) {
    return this.timeline.getOne(userId, id);
  }

  @Patch('timeline/blocks/:id')
  update(@CurrentUser('id') userId: string, @Param('id') id: string, @Body() dto: UpdateBlockDto) {
    return this.timeline.update(userId, id, dto);
  }

  @Delete('timeline/blocks/:id')
  remove(@CurrentUser('id') userId: string, @Param('id') id: string) {
    return this.timeline.remove(userId, id);
  }

  // ── Sync ───────────────────────────────────────────────────────────────────
  @Get('timeline/blocks/:id/sync')
  listSyncs(@CurrentUser('id') userId: string, @Param('id') id: string) {
    return this.timeline.listSyncs(userId, id);
  }

  @Post('timeline/blocks/:id/sync')
  sync(@CurrentUser('id') userId: string, @Param('id') id: string, @Body() dto: SyncBlocksDto) {
    return this.timeline.sync(userId, id, dto.syncs);
  }

  @Delete('timeline/blocks/:id/sync/:groupId')
  removeSync(
    @CurrentUser('id') userId: string,
    @Param('id') id: string,
    @Param('groupId') groupId: string,
  ) {
    return this.timeline.removeSync(userId, id, groupId);
  }
}
