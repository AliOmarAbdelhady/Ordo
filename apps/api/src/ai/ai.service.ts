import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { MemberStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { GroupsService } from '../groups/groups.service';
import { TimelineService } from '../timeline/timeline.service';
import { TasksService } from '../tasks/tasks.service';
import { TodosService } from '../todos/todos.service';
import { AiMember, extractTasks, parseCommand } from '../common/utils/ai';
import { redactBlock } from '../common/utils/visibility';
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

    // The suggestion is client-controlled (only @IsObject at the DTO layer), so
    // validate the fields we consume before dispatching. Downstream services
    // still re-check membership/permissions.
    const ALLOWED_INTENTS = new Set(['CREATE_EVENT', 'CREATE_TASK', 'CREATE_TODO']);
    if (!ALLOWED_INTENTS.has(s.intent)) {
      throw new BadRequestException('Unsupported or empty suggestion intent');
    }
    if (s.title != null && (typeof s.title !== 'string' || s.title.length > 200)) {
      throw new BadRequestException('title must be a string up to 200 characters');
    }
    if (s.assigneeId != null && (typeof s.assigneeId !== 'string' || s.assigneeId.length > 64)) {
      throw new BadRequestException('invalid assigneeId');
    }
    const st = s.startTime ? new Date(s.startTime) : undefined;
    const en = s.endTime ? new Date(s.endTime) : undefined;
    if ((st && isNaN(st.getTime())) || (en && isNaN(en.getTime()))) {
      throw new BadRequestException('startTime/endTime must be valid ISO dates');
    }
    if (st && en && !(st < en)) throw new BadRequestException('Start must be before end');

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

    const [taskCount, pendingTasks, todoCount, eventCount, messageCount, announcements] = await Promise.all([
      this.prisma.task.count({ where: { groupId, deletedAt: null } }),
      this.prisma.task.findMany({
        where: { groupId, deletedAt: null, status: { in: ['TODO', 'IN_PROGRESS', 'BLOCKED'] } },
        orderBy: { dueAt: { nulls: 'first', sort: 'asc' } },
        take: 5,
        select: { id: true, title: true, dueAt: true },
      }),
      this.prisma.todo.count({ where: { groupId, done: false } }),
      this.prisma.timelineBlock.count({ where: { groupId, deletedAt: null, isEvent: true, startTime: { gte: now } } }),
      this.prisma.message.count({ where: { groupId, deletedAt: null } }),
      this.prisma.announcement.count({ where: { groupId } }),
    ]);

    // Privacy: the "next event" must be redacted per the viewer's relationship to
    // each block — a PRIVATE block the viewer doesn't own is skipped, and a
    // BUSY_ONLY block surfaces as "Busy" instead of its real title. The previous
    // raw findFirst leaked raw titles of private/busy blocks.
    const upcoming = await this.nextVisibleEvent(groupId, userId, now, inAWeek);

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
    // Anchor "today" to the user's local midnight (in UTC) so the day window is
    // correct for their timezone, not always the UTC calendar day.
    const { start, end } = this.localDayWindow(now, timezone);

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

  /**
   * Earliest upcoming group EVENT the viewer is allowed to see, privacy-redacted.
   * Walks candidates earliest-first and returns the first redactBlock does NOT
   * suppress (PRIVATE blocks the viewer doesn't own are skipped; BUSY_ONLY
   * surfaces as "Busy"). Only blocks flagged isEvent are considered.
   */
  private async nextVisibleEvent(
    groupId: string,
    viewerId: string,
    from: Date,
    to: Date,
  ): Promise<{ id: string; title: string; startTime: Date } | null> {
    const candidates = await this.prisma.timelineBlock.findMany({
      where: { groupId, deletedAt: null, isEvent: true, startTime: { gte: from, lte: to } },
      orderBy: { startTime: 'asc' },
      take: 30,
    });
    for (const b of candidates) {
      const view = redactBlock(
        {
          id: b.id,
          title: b.title,
          description: b.description,
          startTime: b.startTime,
          endTime: b.endTime,
          color: b.color,
          location: b.location,
          visibility: b.visibility,
          ownerId: b.ownerUserId,
          groupId: b.groupId,
          createdById: b.createdById,
          isEvent: b.isEvent,
          allDay: b.allDay,
          source: b.source,
          reminderMinutesBefore: b.reminderMinutesBefore,
        },
        viewerId,
      );
      if (view) return { id: b.id, title: view.title, startTime: b.startTime };
    }
    return null;
  }

  /** Local-calendar day window [start, start+24h) for the given IANA timezone. */
  private localDayWindow(now: Date, timezone?: string): { start: Date; end: Date } {
    try {
      const tz = timezone || 'UTC';
      const fmt = new Intl.DateTimeFormat('en-US', {
        timeZone: tz,
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
      });
      const parts = fmt.formatToParts(now);
      const get = (t: string) => Number(parts.find((p) => p.type === t)?.value ?? '0');
      const localMidnightUtc = new Date(Date.UTC(get('year'), get('month') - 1, get('day'), 0, 0, 0));
      if (!isNaN(localMidnightUtc.getTime())) {
        return { start: localMidnightUtc, end: new Date(localMidnightUtc.getTime() + 24 * 60 * 60 * 1000) };
      }
    } catch {
      // fall through to UTC
    }
    const start = new Date(now);
    start.setUTCHours(0, 0, 0, 0);
    return { start, end: new Date(start.getTime() + 24 * 60 * 60 * 1000) };
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
