import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { MemberStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { GroupsService } from '../groups/groups.service';
import { TimelineService } from '../timeline/timeline.service';
import { TasksService } from '../tasks/tasks.service';
import { TodosService } from '../todos/todos.service';
import { AiMember, extractTasks, parseCommand } from '../common/utils/ai';
import { ApplySuggestionDto, ExtractTasksDto, ParseCommandDto } from './dto/ai.dto';
import { CreateBlockDto } from '../timeline/dto/timeline.dto';
import { CreateTaskDto } from '../tasks/dto/task.dto';
import { CreateTodoDto } from '../todos/dto/todo.dto';

@Injectable()
export class AiService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly groups: GroupsService,
    private readonly timeline: TimelineService,
    private readonly tasks: TasksService,
    private readonly todos: TodosService,
  ) {}

  private async resolveMembers(groupId?: string): Promise<AiMember[]> {
    if (!groupId) return [];
    const members = await this.prisma.groupMember.findMany({
      where: { groupId, status: MemberStatus.ACTIVE },
      include: { user: { select: { id: true, name: true, username: true } } },
    });
    return members.map((m) => ({ id: m.user.id, name: m.user.name, username: m.user.username ?? undefined }));
  }

  async parseCommand(userId: string, dto: ParseCommandDto) {
    if (dto.groupId) await this.groups.requireMember(dto.groupId, userId);
    const members = await this.resolveMembers(dto.groupId);
    const suggestion = parseCommand(dto.text, { now: new Date(), groupMembers: members });
    const action = await this.recordAction(userId, dto.text, suggestion, dto.groupId);
    return { suggestion, actionId: action.id };
  }

  async extractTasks(userId: string, dto: ExtractTasksDto) {
    if (dto.groupId) await this.groups.requireMember(dto.groupId, userId);
    const members = await this.resolveMembers(dto.groupId);
    const suggestions = dto.messages.flatMap((m) => extractTasks(m, members));
    return { suggestions };
  }

  /**
   * Apply a previously-reviewed suggestion through the normal services, so the
   * exact same permission checks + side effects (notifications, reminders) apply.
   * Never writes directly. (Plan §19.2)
   */
  async apply(userId: string, dto: ApplySuggestionDto) {
    const s = dto.suggestion ?? {};
    const groupId = dto.groupId ?? s.groupId;

    switch (s.intent) {
      case 'CREATE_EVENT': {
        if (!s.startTime || !s.endTime) throw new BadRequestException('Event needs start and end time');
        const blockDto: CreateBlockDto = {
          title: s.title,
          startTime: s.startTime,
          endTime: s.endTime,
          isEvent: true,
          reminderMinutesBefore: s.reminderMinutesBefore,
          ...(groupId ? { groupId } : {}),
        };
        const block = await this.timeline.create(userId, blockDto);
        await this.markApplied(userId, s);
        return { kind: 'event', block };
      }
      case 'CREATE_TASK': {
        if (!groupId) throw new BadRequestException('Tasks need a group');
        const taskDto: CreateTaskDto = {
          groupId,
          title: s.title,
          dueAt: s.dueDate,
          ...(s.assigneeId ? { assigneeIds: [s.assigneeId] } : {}),
        };
        const task = await this.tasks.create(userId, taskDto);
        await this.markApplied(userId, s);
        return { kind: 'task', task };
      }
      case 'CREATE_TODO': {
        const todoDto: CreateTodoDto = {
          title: s.title,
          dueAt: s.dueDate,
          ...(groupId ? { groupId } : {}),
        };
        const todo = await this.todos.create(userId, todoDto);
        await this.markApplied(userId, s);
        return { kind: 'todo', todo };
      }
      default:
        throw new BadRequestException('Unsupported or empty suggestion intent');
    }
  }

  /** Heuristic group summary: counts + upcoming event + pending tasks. */
  async summarizeGroup(userId: string, groupId: string) {
    await this.groups.requireMember(groupId, userId);
    const now = new Date();
    const inAWeek = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);

    const [taskCount, pendingTasks, todoCount, eventCount, upcoming, messageCount, announcements] = await Promise.all([
      this.prisma.task.count({ where: { groupId, deletedAt: null } }),
      this.prisma.task.findMany({
        where: { groupId, deletedAt: null, status: { in: ['TODO', 'IN_PROGRESS', 'BLOCKED'] } },
        orderBy: { dueAt: { nulls: 'first', sort: 'asc' } },
        take: 5,
        select: { id: true, title: true, dueAt: true },
      }),
      this.prisma.todo.count({ where: { groupId, done: false } }),
      this.prisma.timelineBlock.count({ where: { groupId, deletedAt: null, isEvent: true, startTime: { gte: now } } }),
      this.prisma.timelineBlock.findFirst({
        where: { groupId, deletedAt: null, startTime: { gte: now, lte: inAWeek } },
        orderBy: { startTime: 'asc' },
        select: { id: true, title: true, startTime: true },
      }),
      this.prisma.message.count({ where: { groupId, deletedAt: null } }),
      this.prisma.announcement.count({ where: { groupId } }),
    ]);

    const bullets: string[] = [];
    bullets.push(`${taskCount} tasks (${pendingTasks.length} active).`);
    if (pendingTasks.length) bullets.push(`Next up: ${pendingTasks.map((t) => t.title).join(', ')}.`);
    bullets.push(`${todoCount} open to-dos, ${eventCount} upcoming events.`);
    if (upcoming) bullets.push(`Next event: ${upcoming.title}.`);
    bullets.push(`${messageCount} messages sent, ${announcements} announcements.`);

    return {
      summary: bullets.join(' '),
      stats: { taskCount, pendingTasks, todoCount, eventCount, messageCount, announcements },
      upcomingEvent: upcoming
        ? { id: upcoming.id, title: upcoming.title, startTime: upcoming.startTime.toISOString() }
        : null,
    };
  }

  /** Heuristic day plan: today's blocks + tasks due today + open todos. */
  async planDay(userId: string, timezone?: string) {
    const now = new Date();
    const start = new Date(now);
    start.setUTCHours(0, 0, 0, 0);
    const end = new Date(start.getTime() + 24 * 60 * 60 * 1000);

    const [blocks, tasks, todos] = await Promise.all([
      this.timeline.listSelf(userId, start, end),
      this.tasks.listMine(userId),
      this.todos.listMine(userId, 'today'),
    ]);

    const tasksToday = tasks.tasks.filter((t: any) => t.dueAt && new Date(t.dueAt) <= end);
    const bullets: string[] = [];
    if (blocks.items.length) bullets.push(`You have ${blocks.items.length} time blocks today.`);
    if (tasksToday.length) bullets.push(`${tasksToday.length} task(s) due today.`);
    if (todos.todos.length) bullets.push(`${todos.todos.length} to-do(s) to act on.`);
    if (!bullets.length) bullets.push('Your day is open — no scheduled blocks or due tasks.');

    return {
      plan: bullets.join(' '),
      blocks: blocks.items,
      tasksDueToday: tasksToday,
      todosToday: todos.todos,
    };
  }

  private async recordAction(userId: string, input: string, output: any, groupId?: string) {
    return this.prisma.aiAction.create({
      data: {
        userId,
        intent: output.intent ?? 'NONE',
        input: { text: input, groupId: groupId ?? null } as any,
        output: output as any,
        applied: false,
      },
    });
  }

  private async markApplied(userId: string, output: any) {
    await this.prisma.aiAction.create({
      data: {
        userId,
        intent: output.intent ?? 'NONE',
        input: { source: 'apply-suggestion' } as any,
        output: output as any,
        applied: true,
      },
    });
  }
}
