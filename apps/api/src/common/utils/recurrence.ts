import { Interval } from './time';

export interface RecurringBlock {
  startTime: Date;
  endTime: Date;
  recurrenceRule?: string | null;
}

const DAY_NAMES = ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA'];
const MS_PER_DAY = 24 * 60 * 60 * 1000;

interface ParsedRule {
  freq: 'DAILY' | 'WEEKLY' | 'MONTHLY';
  interval: number;
  byDay: number[]; // 0=Sun..6=Sat
  count?: number;
  until?: Date;
}

function parseRule(rule: string): ParsedRule | null {
  const parts = rule.toUpperCase().split(';');
  const map: Record<string, string> = {};
  for (const p of parts) {
    const [k, v] = p.split('=');
    if (k && v) map[k] = v;
  }
  const freq = map.FREQ as ParsedRule['freq'];
  if (!freq || !['DAILY', 'WEEKLY', 'MONTHLY'].includes(freq)) return null;
  const byDay = map.BYDAY
    ? map.BYDAY.split(',').map((d) => DAY_NAMES.indexOf(d)).filter((d) => d >= 0)
    : [];
  let until: Date | undefined;
  if (map.UNTIL) {
    const u = new Date(map.UNTIL);
    if (!isNaN(u.getTime())) until = u;
  }
  return {
    freq,
    interval: Math.max(1, Number(map.INTERVAL) || 1),
    byDay,
    count: map.COUNT ? Number(map.COUNT) : undefined,
    until,
  };
}

function startOfDayUtc(d: Date): Date {
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
}

/**
 * Expand a (possibly recurring) block into concrete occurrences that overlap
 * the [from, to] window. Non-recurring blocks yield a single occurrence.
 *
 * Occurrences repeat at the same UTC wall-clock time of day. Full DST-aware
 * expansion is intentionally out of scope for the MVP.
 */
export function expandRecurrence(
  block: RecurringBlock,
  from: Date,
  to: Date,
): Interval[] {
  const { startTime, endTime, recurrenceRule } = block;
  const duration = endTime.getTime() - startTime.getTime();
  const result: Interval[] = [];

  if (!recurrenceRule) {
    if (startTime < to && endTime > from) {
      result.push({ start: startTime, end: endTime });
    }
    return result;
  }

  const rule = parseRule(recurrenceRule);
  if (!rule) {
    if (startTime < to && endTime > from) result.push({ start: startTime, end: endTime });
    return result;
  }

  const baseTimeMs =
    startTime.getUTCHours() * 3_600_000 +
    startTime.getUTCMinutes() * 60_000 +
    startTime.getUTCSeconds() * 1000;
  const baseDay = startOfDayUtc(startTime);
  const baseWeekStart = new Date(baseDay.getTime() - startTime.getUTCDay() * MS_PER_DAY);
  const baseMonth = startTime.getUTCMonth();
  const baseYear = startTime.getUTCFullYear();
  const baseDate = startTime.getUTCDate();

  const hardStop = rule.until && rule.until < to ? rule.until : to;
  const windowStart = startOfDayUtc(from.getTime() < baseDay.getTime() ? from : baseDay);
  // step backwards a couple of days so a block starting just before `from` still shows.
  const cursor = new Date(windowStart.getTime() - MS_PER_DAY);
  const absStop = new Date(hardStop.getTime() + MS_PER_DAY);

  let emitted = 0;
  let guard = 0;
  while (cursor.getTime() <= absStop.getTime() && guard < 2000) {
    guard++;

    let matches = false;
    const weekdayOk = rule.byDay.length === 0 || rule.byDay.includes(cursor.getUTCDay());
    if (weekdayOk) {
      if (rule.freq === 'DAILY') {
        const daysDiff = Math.round((cursor.getTime() - baseDay.getTime()) / MS_PER_DAY);
        matches = daysDiff >= 0 && daysDiff % rule.interval === 0;
      } else if (rule.freq === 'WEEKLY') {
        const weeksDiff = Math.round((cursor.getTime() - baseWeekStart.getTime()) / (MS_PER_DAY * 7));
        matches = weeksDiff >= 0 && weeksDiff % rule.interval === 0;
      } else if (rule.freq === 'MONTHLY') {
        const monthsDiff =
          (cursor.getUTCFullYear() - baseYear) * 12 + (cursor.getUTCMonth() - baseMonth);
        // Clamp the base day-of-month to the target month's length so a monthly
        // recurrence on the 29th/30th/31st still occurs in shorter months
        // (e.g. the 31st lands on the 28th in February), instead of silently
        // skipping those months.
        const daysInMonth = new Date(
          Date.UTC(cursor.getUTCFullYear(), cursor.getUTCMonth() + 1, 0),
        ).getUTCDate();
        const targetDay = Math.min(baseDate, daysInMonth);
        matches =
          monthsDiff >= 0 && monthsDiff % rule.interval === 0 && cursor.getUTCDate() === targetDay;
      }
    }

    if (matches) {
      if (rule.count && emitted >= rule.count) break;
      const occurrenceStart = new Date(cursor.getTime() + baseTimeMs);
      const occurrenceEnd = new Date(occurrenceStart.getTime() + duration);
      emitted++;
      if (occurrenceStart < hardStop && occurrenceEnd > from) {
        result.push({ start: occurrenceStart, end: occurrenceEnd });
      }
    }

    cursor.setUTCDate(cursor.getUTCDate() + 1);
  }

  return result.sort((a, b) => a.start.getTime() - b.start.getTime());
}
