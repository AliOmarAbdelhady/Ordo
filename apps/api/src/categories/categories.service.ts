import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { GroupsService } from '../groups/groups.service';
import { CreateCategoryDto } from './dto/category.dto';

@Injectable()
export class CategoriesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly groups: GroupsService,
  ) {}

  async list(userId: string, groupId?: string) {
    if (groupId) {
      await this.groups.requireMember(groupId, userId);
      const cats = await this.prisma.timelineCategory.findMany({ where: { groupId } });
      return { categories: cats };
    }
    const cats = await this.prisma.timelineCategory.findMany({ where: { userId } });
    return { categories: cats };
  }

  async create(userId: string, dto: CreateCategoryDto) {
    if (dto.groupId) {
      await this.groups.requireMember(dto.groupId, userId);
    }
    return this.prisma.timelineCategory.create({
      data: {
        name: dto.name,
        color: dto.color ?? '#2563EB',
        userId: dto.groupId ? null : userId,
        groupId: dto.groupId ?? null,
      },
    });
  }

  async remove(userId: string, id: string) {
    const cat = await this.prisma.timelineCategory.findUnique({ where: { id } });
    if (!cat) throw new NotFoundException('Category not found');
    if (cat.userId && cat.userId !== userId) throw new ForbiddenException('Not your category');
    if (cat.groupId) await this.groups.requireMember(cat.groupId, userId);
    await this.prisma.timelineCategory.delete({ where: { id } });
    return { ok: true };
  }
}
