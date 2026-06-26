/**
 * Heuristic natural-language command parser for the Ordo AI assistant.
 *
 * This is a deterministic, dependency-free parser (no external LLM) that turns
 * common scheduling phrases into structured JSON suggestions. It deliberately
 * errs on the side of low confidence and leaves action execution to the normal
 * services after the user confirms (plan §19.4). A production deployment can
 * swap `parseCommand` for an LLM-backed implementation that returns the same
 * shape — the rest of the system does not change.
 *
 * Wall-clock times parsed from text are interpreted as UTC for determinism; the
 * user reviews and confirms every suggestion before it becomes a real block.
 */

export interface AiMember {
  id: string;
  name: string;
  username?: string;
}

export interface AiContext {
  now: Date;
  timezone?: string;
  groupMembers?: AiMember[];
}

export type AiIntent =
  | 'CREATE_EVENT'
  | 'CREATE_TASK'
  | 'CREATE_TODO'
  | 'REMINDER'
  | 'SUMMARY'
  | 'NONE';

export interface AiSuggestion {
  intent: AiIntent;
  title: string;
  startTime?: string;
  endTime?: string;
  durationMinutes?: number;
  assigneeName?: string;
  assigneeId?: string;
  dueDate?: string;
  reminderMinutesBefore?: number;
  confidence: number;
  raw: string;
}

const WEEKDAYS = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
const SHORT_WEEKDAYS = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];

/** Find an explicit clock time like "8 pm", "7:30", "20:00", "at 5". */
function findClockTime(text: string): { hour: number; minute: number } | null {
  const re = /\b(\d{1,2})(?::(\d{2}))?\s*(a\.?m\.?|p\.?m\.?)?\b/i;
  const m = text.match(re);
  if (!m) return null;
  let hour = Number(m[1]);
  const minute = m[2] ? Number(m[2]) : 0;
  if (hour > 23 || minute > 59) return null;
  const meridiem = m[3]?.toLowerCase().replace(/\./g, '');
  if (meridiem === 'pm' && hour < 12) hour += 12;
  if (meridiem === 'am' && hour === 12) hour = 0;
  // A bare number with no meridiem is ambiguous — only treat 7-11 as evening-ish
  // when "tonight"/"evening" is present, otherwise leave hour as-is.
  return { hour, minute };
}

/** Day offset from `now` for tokens like "today", "tomorrow", "monday", "next friday". */
function findDayOffset(text: string, now: Date): number | null {
  const lower = text.toLowerCase();
  if (/\btomorrow\b|\btmr\b|\btmrw\b/.test(lower)) return 1;
  if (/\bafter\s+tomorrow\b|\bday\s+after\s+tomorrow\b/.test(lower)) return 2;
  if (/\btoday\b|\btonight\b/.test(lower)) return 0;

  const next = /\bnext\s+([a-z]+)/.exec(lower);
  const dayWord = next ? next[1] : null;
  if (dayWord) {
    const idx = WEEKDAYS.indexOf(dayWord) >= 0 ? WEEKDAYS.indexOf(dayWord) : SHORT_WEEKDAYS.indexOf(dayWord.slice(0, 3));
    if (idx >= 0) {
      let diff = idx - now.getUTCDay();
      if (diff <= 0) diff += 7;
      return diff;
    }
  }
  for (let i = 0; i < 7; i++) {
    const re = new RegExp(`\\b${WEEKDAYS[i]}\\b|\\b${SHORT_WEEKDAYS[i]}\\b`);
    if (re.test(lower)) {
      let diff = i - now.getUTCDay();
      if (diff < 0) diff += 7;
      return diff; // nearest upcoming occurrence
    }
  }
  return null;
}

function composeStart(now: Date, dayOffset: number | null, hour: number, minute: number): Date {
  const base = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), hour, minute, 0, 0));
  if (dayOffset) base.setUTCDate(base.getUTCDate() + dayOffset);
  return base;
}

/** Extract a duration phrase like "for 2 hours", "1.5h", "30 min". */
function findDurationMinutes(text: string): number | null {
  const h = /(\d+(?:\.\d+)?)\s*(?:h|hr|hrs|hour|hours)\b/i.exec(text);
  if (h) return Math.round(Number(h[1]) * 60);
  const m = /(\d+)\s*(?:m|min|mins|minute|minutes)\b/i.exec(text);
  if (m) return Number(m[1]);
  return null;
}

/** Resolve an assignee: "@username", "Name", or "remind <Name> to". */
function findAssignee(text: string, members: AiMember[] = []): { name?: string; id?: string } | null {
  const at = /@([a-z0-9_]+)/i.exec(text);
  if (at) {
    const u = members.find((m) => m.username?.toLowerCase() === at[1].toLowerCase());
    if (u) return { name: u.name, id: u.id };
    return { name: at[1] };
  }
  // "remind <Name> to ...", "<Name> should/needs to/will ..."
  const remind = /\b(?:remind|ask|tell|have)\s+([A-Z][a-zA-Z]+)\b/.exec(text);
  if (remind) {
    const name = remind[1];
    const u = members.find((m) => m.name.toLowerCase() === name.toLowerCase());
    return { name, id: u?.id };
  }
  const subject = /^([A-Z][a-zA-Z]+)\s+(?:should|needs to|will|to|please)\b/.exec(text);
  if (subject) {
    const name = subject[1];
    if (['i', 'we', 'you', 'they'].includes(name.toLowerCase())) return null;
    const u = members.find((m) => m.name.toLowerCase() === name.toLowerCase());
    return { name, id: u?.id };
  }
  return null;
}

function cleanTitle(text: string): string {
  return text
    .replace(/\b(please|kindly|can you|could you|i need to|i want to|let'?s|we should|remind me to)\b/gi, '')
    .replace(/@\w+/g, '')
    .replace(/\b(at|on|by|for|tomorrow|today|tonight|next)\b\s+\S+/gi, '')
    .replace(/\d{1,2}(:\d{2})?\s*(a\.?m\.?|p\.?m\.?)?/gi, '')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/^[-–—:,\s]+|[-–—:,\s]+$/g, '');
}

/**
 * Parse a natural-language command into a structured suggestion.
 * Returns intent NONE with the raw text when nothing is recognised.
 */
export function parseCommand(input: string, ctx: AiContext): AiSuggestion {
  const text = input.trim();
  const lower = text.toLowerCase();
  const members = ctx.groupMembers ?? [];
  const raw = text;

  if (!text) {
    return { intent: 'NONE', title: '', confidence: 0, raw };
  }

  const wantsSummary = /\b(summar(i[sz]e|z)|summary|digest|recap|what (did|happened))\b/.test(lower);
  if (wantsSummary) {
    return { intent: 'SUMMARY', title: text, confidence: 0.6, raw };
  }

  const clock = findClockTime(text);
  const dayOffset = findDayOffset(text, ctx.now);
  const duration = findDurationMinutes(text);
  const assignee = findAssignee(text, members);

  const isEvent = /\b(event|meeting|meet|dinner|lunch|session|class|game|practice|appoint|schedule|plan|book)\b/.test(lower)
    || (!!clock && /\b(at|on|tomorrow|today|tonight)\b/.test(lower) && !assignee);
  const isTask = /\b(task|assign|bring|prepare|finish|submit|upload|complete|do)\b/.test(lower) || !!assignee;
  const isTodo = /\b(todo|to-do|remember to|buy|pick up|get)\b/.test(lower);
  const wantsReminder = /\bremind|reminder|alert\b/.test(lower);

  // Reminder lead: "remind me to X at 8pm" → a TODO with a reminder, or a task.
  if (wantsReminder && !clock) {
    const title = cleanTitle(text.replace(/\bremind me to\b/i, '').replace(/\bremind\b/i, '')) || 'Reminder';
    return {
      intent: 'REMINDER',
      title,
      assigneeName: assignee?.name,
      assigneeId: assignee?.id,
      reminderMinutesBefore: 0,
      confidence: 0.55,
      raw,
    };
  }

  if (isEvent && clock) {
    const start = composeStart(ctx.now, dayOffset, clock.hour, clock.minute);
    const mins = duration ?? 60;
    const end = new Date(start.getTime() + mins * 60_000);
    const reminder = /(\d+)\s*(hour|hr|minute|min)\s+before/i.test(lower) ? 60 : null;
    const title = cleanTitle(text) || 'New event';
    return {
      intent: 'CREATE_EVENT',
      title,
      startTime: start.toISOString(),
      endTime: end.toISOString(),
      durationMinutes: mins,
      reminderMinutesBefore: reminder ?? undefined,
      confidence: 0.7,
      raw,
    };
  }

  if (isTask) {
    const title = cleanTitle(text) || 'New task';
    const due = dayOffset != null ? composeStart(ctx.now, dayOffset, 23, 59).toISOString() : undefined;
    return {
      intent: 'CREATE_TASK',
      title,
      assigneeName: assignee?.name,
      assigneeId: assignee?.id,
      dueDate: due,
      confidence: 0.6,
      raw,
    };
  }

  if (isTodo) {
    const title = cleanTitle(text) || 'New to-do';
    const due = dayOffset != null ? composeStart(ctx.now, dayOffset, 23, 59).toISOString() : undefined;
    return { intent: 'CREATE_TODO', title, dueDate: due, confidence: 0.5, raw };
  }

  return { intent: 'NONE', title: text, confidence: 0.2, raw };
}

/** Heuristic task extraction from a chat message. Returns [] when nothing looks actionable. */
export function extractTasks(message: string, members: AiMember[] = []): AiSuggestion[] {
  const sentences = message.split(/(?<=[.!?])\s+|\n+/).map((s) => s.trim()).filter(Boolean);
  const out: AiSuggestion[] = [];
  for (const s of sentences) {
    const lower = s.toLowerCase();
    const looksActionable =
      /\b(please|can you|could you|need to|should|will|let'?s|remember to|don'?t forget|bring|prepare|submit|finish|upload|remind)\b/.test(lower)
      || /@[a-z0-9_]+/i.test(s)
      || /\b(tomorrow|today|tonight|by\s+\w+)/i.test(s);
    if (!looksActionable) continue;
    const parsed = parseCommand(s, { now: new Date('2026-06-26T12:00:00Z'), groupMembers: members });
    if (parsed.intent === 'CREATE_TASK' || parsed.intent === 'CREATE_TODO') {
      out.push(parsed);
    } else if (looksActionable && s.length > 3) {
      out.push({ intent: 'CREATE_TASK', title: cleanTitle(s) || s, confidence: 0.4, raw: s });
    }
  }
  return out;
}
