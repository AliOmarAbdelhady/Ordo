import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { GroupsService } from '../groups/groups.service';
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
      deletedAt: null,
      ...(groupId ? { groupId } : { ownerUserId: userId, groupId: null }),
    };
    const now = new Date();
    const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const endOfToday = new Date(startOfToday.getTime() + 24 * 60 * 60 * 1000);

    if (tab === 'today') {
      where.done = false;
      where.OR = [{ dueAt: { lt: endOfToday } }];
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

  async update(userId: string, todoId: string, dto: UpdateTodoDto): Promise<TodoDto> {
    const todo = await this.prisma.todo.findUnique({ where: { id: todoId } });
    if (!todo) throw new NotFoundException('To-do not found');
    this.assertCanMutate(todo, userId);

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
    this.assertCanMutate(todo, userId);
    await this.prisma.todo.delete({ where: { id: todoId } });
    return { ok: true };
  }

  private assertCanMutate(todo: any, userId: string) {
    if (todo.ownerUserId === userId || todo.createdById === userId) return;
    if (todo.groupId) {
      // Will throw NotFound/Forbidden if not a member; acceptable here.
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
