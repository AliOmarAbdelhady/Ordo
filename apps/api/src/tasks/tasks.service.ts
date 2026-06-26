import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { MemberStatus, TaskStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { GroupsService } from '../groups/groups.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CreateTaskDto, UpdateTaskDto } from './dto/task.dto';

export type TaskTab = 'all' | 'mine' | 'assigned_by_me' | 'late' | 'done';

export interface TaskDto {
  id: string;
  groupId: string;
  title: string;
  description: string | null;
  status: TaskStatus;
  priority: string;
  dueAt: string | null;
  createdAt: string;
  updatedAt: string;
  createdBy: { id: string; name: string; avatarUrl: string | null };
  assignees: { id: string; name: string; avatarUrl: string | null }[];
  commentCount: number;
  /** Only populated by the cross-group "mine" view (provenance). */
  group?: { id: string; name: string; accentColor: string } | null;
}

@Injectable()
export class TasksService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly groups: GroupsService,
    private readonly notifications: NotificationsService,
  ) {}

  async create(userId: string, dto: CreateTaskDto): Promise<TaskDto> {
    await this.groups.requirePermission(dto.groupId, userId, 'TASK_CREATE');
    let assigneeIds = dto.assigneeIds ?? [];
    if (assigneeIds.length) {
      await this.groups.requirePermission(dto.groupId, userId, 'TASK_ASSIGN');
      // Validate assignees are members.
      const valid = await this.prisma.groupMember.findMany({
        where: { groupId: dto.groupId, userId: { in: assigneeIds }, status: MemberStatus.ACTIVE },
        select: { userId: true },
      });
      assigneeIds = valid.map((m) => m.userId);
    }

    const task = await this.prisma.task.create({
      data: {
        groupId: dto.groupId,
        createdById: userId,
        title: dto.title,
        description: dto.description,
        priority: dto.priority,
        status: dto.status,
        dueAt: dto.dueAt ? new Date(dto.dueAt) : undefined,
        assignees: assigneeIds.length ? { create: assigneeIds.map((id) => ({ userId: id })) } : undefined,
      },
      include: this.include(),
    });

    if (assigneeIds.length) {
      await this.notifications.createMany(
        assigneeIds
          .filter((id) => id !== userId)
          .map((id) => ({
            userId: id,
            type: 'TASK_ASSIGNED' as const,
            title: 'New task assigned to you',
            body: dto.title,
            data: { groupId: dto.groupId, taskId: task.id },
          })),
      );
    }
    return this.toDto(task);
  }

  async list(userId: string, groupId: string, tab: TaskTab) {
    await this.groups.requireMember(groupId, userId);
    const now = new Date();
    const where: any = { groupId, deletedAt: null };
    if (tab === 'mine') where.assignees = { some: { userId } };
    if (tab === 'assigned_by_me') where.createdById = userId;
    if (tab === 'late') where.dueAt = { lt: now };
    if (tab === 'late') where.status = { notIn: [TaskStatus.DONE, TaskStatus.CANCELLED] };
    if (tab === 'done') where.status = TaskStatus.DONE;

    const tasks = await this.prisma.task.findMany({
      where,
      include: this.include(),
      orderBy: [{ status: 'asc' }, { dueAt: { nulls: 'first', sort: 'asc' } }, { createdAt: 'desc' }],
      take: 100,
    });
    return { tasks: tasks.map((t) => this.toDto(t)) };
  }

  /**
   * Cross-group "mine" view for the unified dashboard: every task assigned to
   * the user across all groups they belong to, each enriched with the owning
   * group's name/accent so the dashboard can show provenance. Membership is the
   * authorization gate — only tasks in groups the user is an active member of
   * are returned.
   */
  async listMine(userId: string) {
    const memberships = await this.prisma.groupMember.findMany({
      where: { userId, status: MemberStatus.ACTIVE },
      select: { groupId: true },
    });
    const groupIds = memberships.map((m) => m.groupId);
    if (!groupIds.length) return { tasks: [] };

    const tasks = await this.prisma.task.findMany({
      where: { groupId: { in: groupIds }, deletedAt: null, assignees: { some: { userId } } },
      include: {
        ...this.include(),
        group: { select: { id: true, name: true, accentColor: true } },
      },
      orderBy: [{ status: 'asc' }, { dueAt: { nulls: 'first', sort: 'asc' } }, { createdAt: 'desc' }],
      take: 200,
    });
    return { tasks: tasks.map((t) => this.toDto(t)) };
  }

  async getOne(userId: string, taskId: string) {
    const task = await this.prisma.task.findUnique({ where: { id: taskId }, include: this.include() });
    if (!task || task.deletedAt) throw new NotFoundException('Task not found');
    await this.groups.requireMember(task.groupId, userId);
    const comments = await this.prisma.taskComment.findMany({
      where: { taskId },
      include: { user: { select: { id: true, name: true, avatarUrl: true } } },
      orderBy: { createdAt: 'asc' },
    });
    return {
      ...this.toDto(task),
      comments: comments.map((c) => ({
        id: c.id,
        body: c.body,
        createdAt: c.createdAt.toISOString(),
        user: c.user,
      })),
    };
  }

  async update(userId: string, taskId: string, dto: UpdateTaskDto): Promise<TaskDto> {
    const task = await this.prisma.task.findUnique({ where: { id: taskId }, include: this.include() });
    if (!task || task.deletedAt) throw new NotFoundException('Task not found');

    const isCreator = task.createdById === userId;
    const isAssignee = task.assignees.some((a) => a.userId === userId);
    if (!isCreator && !isAssignee) {
      await this.groups.requirePermission(task.groupId, userId, 'TASK_UPDATE_ANY');
    }

    let assigneeIds: string[] | undefined;
    if (dto.assigneeIds) {
      await this.groups.requirePermission(task.groupId, userId, 'TASK_ASSIGN');
      const valid = await this.prisma.groupMember.findMany({
        where: { groupId: task.groupId, userId: { in: dto.assigneeIds }, status: MemberStatus.ACTIVE },
        select: { userId: true },
      });
      assigneeIds = valid.map((m) => m.userId);
    }

    const updated = await this.prisma.task.update({
      where: { id: taskId },
      data: {
        title: dto.title,
        description: dto.description,
        priority: dto.priority,
        status: dto.status,
        dueAt: dto.dueAt !== undefined ? (dto.dueAt ? new Date(dto.dueAt) : null) : undefined,
        ...(assigneeIds
          ? {
              assignees: {
                deleteMany: {},
                create: assigneeIds.map((id) => ({ userId: id })),
              },
            }
          : {}),
      },
      include: this.include(),
    });

    // Notify newly assigned users.
    if (assigneeIds) {
      const previous = new Set(task.assignees.map((a) => a.userId));
      const added = assigneeIds.filter((id) => !previous.has(id) && id !== userId);
      if (added.length) {
        await this.notifications.createMany(
          added.map((id) => ({
            userId: id,
            type: 'TASK_ASSIGNED' as const,
            title: 'New task assigned to you',
            body: updated.title,
            data: { groupId: task.groupId, taskId },
          })),
        );
      }
    }
    return this.toDto(updated);
  }

  async remove(userId: string, taskId: string) {
    const task = await this.prisma.task.findUnique({ where: { id: taskId } });
    if (!task || task.deletedAt) throw new NotFoundException('Task not found');
    if (task.createdById !== userId) {
      await this.groups.requirePermission(task.groupId, userId, 'TASK_DELETE_ANY');
    }
    await this.prisma.task.update({ where: { id: taskId }, data: { deletedAt: new Date() } });
    return { ok: true };
  }

  async addComment(userId: string, taskId: string, body: string) {
    const task = await this.prisma.task.findUnique({ where: { id: taskId } });
    if (!task || task.deletedAt) throw new NotFoundException('Task not found');
    await this.groups.requireMember(task.groupId, userId);
    const comment = await this.prisma.taskComment.create({
      data: { taskId, userId, body },
      include: { user: { select: { id: true, name: true, avatarUrl: true } } },
    });
    return {
      id: comment.id,
      body: comment.body,
      createdAt: comment.createdAt.toISOString(),
      user: comment.user,
    };
  }

  private include() {
    return {
      createdBy: { select: { id: true, name: true, avatarUrl: true } },
      assignees: { include: { user: { select: { id: true, name: true, avatarUrl: true } } } },
      _count: { select: { comments: true } },
    };
  }

  private toDto(t: any): TaskDto {
    return {
      id: t.id,
      groupId: t.groupId,
      title: t.title,
      description: t.description,
      status: t.status,
      priority: t.priority,
      dueAt: t.dueAt ? t.dueAt.toISOString() : null,
      createdAt: t.createdAt.toISOString(),
      updatedAt: t.updatedAt.toISOString(),
      createdBy: t.createdBy,
      assignees: (t.assignees ?? []).map((a: any) => a.user),
      commentCount: t._count?.comments ?? 0,
      ...(t.group ? { group: { id: t.group.id, name: t.group.name, accentColor: t.group.accentColor } } : {}),
    };
  }
}
