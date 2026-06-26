import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { MemberStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { GroupsService } from '../groups/groups.service';
import { can, Permission } from '../common/permissions';
import { CreateTodoDto, UpdateTodoDto } from './dto/todo.dto';

export type TodoTab = 'today' | 'upcoming' | 'no_date' | 'done';

export interface TodoDto {
  id: string;
  title: string;
  note: string | null;
  done: boolean;
  dueAt: string | null;
  order: number;
  labels: string[];
  groupId: string | null;
  createdAt: string;
  /** Only populated by the cross-group "mine" view (provenance). */
  group?: { id: string; name: string; accentColor: string } | null;
}

@Injectable()
export class TodosService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly groups: GroupsService,
  ) {}

  async create(userId: string, dto: CreateTodoDto): Promise<TodoDto> {
    let groupId: string | null = null;
    let ownerUserId: string | null = userId;
    if (dto.groupId) {
      await this.groups.requirePermission(dto.groupId, userId, 'TODO_CREATE');
      groupId = dto.groupId;
      ownerUserId = null;
    }
    const todo = await this.prisma.todo.create({
      data: {
        title: dto.title,
        note: dto.note,
        groupId,
        ownerUserId,
        dueAt: dto.dueAt ? new Date(dto.dueAt) : undefined,
        labels: dto.labels ?? [],
        createdById: userId,
      },
    });
    return this.toDto(todo);
  }

  async list(userId: string, groupId: string | null, tab: TodoTab): Promise<{ todos: TodoDto[] }> {
    if (groupId) {
      await this.groups.requireMember(groupId, userId);
    }
    const where: any = {
      ...(groupId ? { groupId } : { ownerUserId: userId, groupId: null }),
    };
    const now = new Date();
    const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const endOfToday = new Date(startOfToday.getTime() + 24 * 60 * 60 * 1000);

    if (tab === 'today') {
      where.done = false;
      // Today = overdue + due today + undated (act-on-now items). Without the
      // undated clause, a freshly added to-do (no due date) is invisible here.
      where.OR = [{ dueAt: { lt: endOfToday } }, { dueAt: null }];
    } else if (tab === 'upcoming') {
      where.done = false;
      where.dueAt = { gte: endOfToday };
    } else if (tab === 'no_date') {
      where.done = false;
      where.dueAt = null;
    } else if (tab === 'done') {
      where.done = true;
    }

    const todos = await this.prisma.todo.findMany({
      where,
      orderBy: [{ order: 'asc' }, { createdAt: 'desc' }],
    });
    return { todos: todos.map((t) => this.toDto(t)) };
  }

  /**
   * Cross-group "mine" view for the unified dashboard: the user's personal
   * to-dos PLUS to-dos in every group they are an active member of, each
   * enriched with group provenance. Personal to-dos carry group = null.
   */
  async listMine(userId: string, tab: TodoTab): Promise<{ todos: TodoDto[] }> {
    const memberships = await this.prisma.groupMember.findMany({
      where: { userId, status: MemberStatus.ACTIVE },
      select: { groupId: true },
    });
    const groupIds = memberships.map((m) => m.groupId);
    // Todo has no `group` relation, so fetch the owning groups separately for
    // provenance and attach by id below.
    const groups = groupIds.length
      ? await this.prisma.group.findMany({
          where: { id: { in: groupIds } },
          select: { id: true, name: true, accentColor: true },
        })
      : [];
    const groupById = new Map(groups.map((g) => [g.id, g]));

    const now = new Date();
    const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const endOfToday = new Date(startOfToday.getTime() + 24 * 60 * 60 * 1000);

    let tabFilter: any;
    if (tab === 'today') {
      tabFilter = { done: false, OR: [{ dueAt: { lt: endOfToday } }, { dueAt: null }] };
    } else if (tab === 'upcoming') {
      tabFilter = { done: false, dueAt: { gte: endOfToday } };
    } else if (tab === 'no_date') {
      tabFilter = { done: false, dueAt: null };
    } else if (tab === 'done') {
      tabFilter = { done: true };
    } else {
      tabFilter = {};
    }

    // Personal (owner) + every group the user belongs to.
    const scope = groupIds.length
      ? { OR: [{ ownerUserId: userId, groupId: null }, { groupId: { in: groupIds } }] }
      : { ownerUserId: userId, groupId: null };

    const todos = await this.prisma.todo.findMany({
      where: { AND: [scope, tabFilter] } as any,
      orderBy: [{ done: 'asc' }, { order: 'asc' }, { createdAt: 'desc' }],
      take: 200,
    });
    return {
      todos: todos.map((t) => ({
        ...this.toDto(t),
        group: t.groupId ? groupById.get(t.groupId) ?? null : null,
      })),
    };
  }

  async update(userId: string, todoId: string, dto: UpdateTodoDto): Promise<TodoDto> {
    const todo = await this.prisma.todo.findUnique({ where: { id: todoId } });
    if (!todo) throw new NotFoundException('To-do not found');

    const isOwnerCreator = todo.ownerUserId === userId || todo.createdById === userId;
    if (!isOwnerCreator) {
      if (!todo.groupId) throw new NotFoundException('To-do not found');
      // Group to-do: a plain member may only toggle `done` (collaborative
      // completion). Editing content (title/note/labels/dueAt/order) requires
      // the creator or an admin (TODO_UPDATE_ANY) — previously any member could
      // rewrite or hard-delete to-dos created by anyone.
      const membership = await this.groups.requireMember(todo.groupId, userId);
      if (!can(membership.role, 'TODO_UPDATE_ANY')) {
        const touchesContent =
          dto.title !== undefined ||
          dto.note !== undefined ||
          dto.labels !== undefined ||
          dto.dueAt !== undefined ||
          dto.order !== undefined;
        if (touchesContent) {
          throw new ForbiddenException('Only the creator or an admin can edit this to-do');
        }
      }
    }

    const updated = await this.prisma.todo.update({
      where: { id: todoId },
      data: {
        title: dto.title,
        note: dto.note,
        done: dto.done,
        order: dto.order,
        labels: dto.labels,
        dueAt: dto.dueAt === null ? null : dto.dueAt ? new Date(dto.dueAt) : undefined,
      },
    });
    return this.toDto(updated);
  }

  async reorder(userId: string, ids: string[]) {
    // Reordering the shared list only sets `order`; it is allowed for members.
    // Personal/foreign to-dos still require ownership so cross-user reorders are
    // rejected.
    const todos = await this.prisma.todo.findMany({ where: { id: { in: ids } } });
    if (todos.length !== ids.length) throw new NotFoundException('To-do not found');
    for (const todo of todos) {
      if (todo.ownerUserId === userId || todo.createdById === userId) continue;
      if (todo.groupId) {
        await this.groups.requireMember(todo.groupId, userId);
      } else {
        throw new NotFoundException('To-do not found');
      }
    }
    await Promise.all(
      ids.map((id, index) =>
        this.prisma.todo.updateMany({ where: { id }, data: { order: index } }),
      ),
    );
    return { ok: true };
  }

  async remove(userId: string, todoId: string) {
    const todo = await this.prisma.todo.findUnique({ where: { id: todoId } });
    if (!todo) throw new NotFoundException('To-do not found');
    await this.assertCanMutate(todo, userId, 'TODO_DELETE_ANY');
    await this.prisma.todo.delete({ where: { id: todoId } });
    return { ok: true };
  }

  private async assertCanMutate(todo: any, userId: string, permission: Permission): Promise<void> {
    if (todo.ownerUserId === userId || todo.createdById === userId) return;
    if (todo.groupId) {
      await this.groups.requirePermission(todo.groupId, userId, permission);
      return;
    }
    throw new NotFoundException('To-do not found');
  }

  private toDto(t: any): TodoDto {
    return {
      id: t.id,
      title: t.title,
      note: t.note,
      done: t.done,
      dueAt: t.dueAt ? t.dueAt.toISOString() : null,
      order: t.order,
      labels: t.labels ?? [],
      groupId: t.groupId,
      createdAt: t.createdAt.toISOString(),
    };
  }
}
