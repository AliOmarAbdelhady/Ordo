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
import { GroupType } from '@prisma/client';
import { GroupsService } from './groups.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { CreateGroupDto, UpdateGroupDto, UpdateMemberDto, PinGroupDto } from './dto/group.dto';

@Controller('groups')
export class GroupsController {
  constructor(private readonly groups: GroupsService) {}

  @Get('templates')
  templates() {
    return { templates: this.groups.templateList() };
  }

  @Post()
  create(@CurrentUser('id') userId: string, @Body() dto: CreateGroupDto) {
    return this.groups.create(userId, dto);
  }

  @Get()
  list(@CurrentUser('id') userId: string, @Query('type') type?: GroupType) {
    return this.groups.list(userId, type);
  }

  @Post('join')
  join(@CurrentUser('id') userId: string, @Body() body: { code: string }) {
    return this.groups.joinByCode(userId, body.code);
  }

  @Get(':groupId')
  get(@CurrentUser('id') userId: string, @Param('groupId') groupId: string) {
    return this.groups.get(userId, groupId);
  }

  @Patch(':groupId')
  update(@CurrentUser('id') userId: string, @Param('groupId') groupId: string, @Body() dto: UpdateGroupDto) {
    return this.groups.update(userId, groupId, dto);
  }

  @Delete(':groupId')
  remove(@CurrentUser('id') userId: string, @Param('groupId') groupId: string) {
    return this.groups.remove(userId, groupId);
  }

  @Post(':groupId/leave')
  leave(@CurrentUser('id') userId: string, @Param('groupId') groupId: string) {
    return this.groups.leave(userId, groupId);
  }

  @Post(':groupId/invite')
  invite(@CurrentUser('id') userId: string, @Param('groupId') groupId: string) {
    return this.groups.invite(userId, groupId);
  }

  @Patch(':groupId/pin')
  pin(
    @CurrentUser('id') userId: string,
    @Param('groupId') groupId: string,
    @Body() dto: PinGroupDto,
  ) {
    return this.groups.setPinned(userId, groupId, dto.pinned);
  }

  @Get(':groupId/members')
  members(@CurrentUser('id') userId: string, @Param('groupId') groupId: string) {
    return this.groups.listMembers(userId, groupId);
  }

  @Patch(':groupId/members/:memberId')
  updateMember(
    @CurrentUser('id') userId: string,
    @Param('groupId') groupId: string,
    @Param('memberId') memberId: string,
    @Body() dto: UpdateMemberDto,
  ) {
    return this.groups.updateMember(userId, groupId, memberId, dto.role as any);
  }

  @Delete(':groupId/members/:memberId')
  removeMember(
    @CurrentUser('id') userId: string,
    @Param('groupId') groupId: string,
    @Param('memberId') memberId: string,
  ) {
    return this.groups.removeMember(userId, groupId, memberId);
  }
}
