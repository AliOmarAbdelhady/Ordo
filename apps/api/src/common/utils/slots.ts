import { Interval, localHour } from './time';

export interface MemberAvailability {
  memberId: string;
  intervals: Interval[]; // busy intervals (already expanded + timezone-normalized)
  timezone: string;
  sleepStartMin: number; // local minutes since midnight
  sleepEndMin: number;
  weekdays: number[]; // 0=Sun..6=Sat ; empty = any day
}

export interface SlotFindInput {
  rangeStart: Date;
  rangeEnd: Date;
  durationMinutes: number;
  members: MemberAvailability[];
  requiredMemberIds: string[];
  minimumAvailableCount: number;
  preferredTimeWindows?: string[]; // morning | afternoon | evening | night
  timezone: string;
  gridMinutes?: number;
  maxResults?: number;
}

export interface SlotResult {
  start: string;
  end: string;
  availableCount: number;
  totalCount: number;
  unavailableMemberIds: string[];
  score: number;
  window: string;
}

const STEP = 15; // minutes grid

function localMinutes(date: Date, timezone: string): number {
  try {
    const formatted = new Intl.DateTimeFormat('en-US', {
      timeZone: timezone,
      hour: '2-digit',
      minute: '2-digit',
      hour12: false,
    }).format(date);
    const [h, m] = formatted.split(':').map(Number);
    return ((h % 24) * 60 + m) % 1440;
  } catch {
    return date.getUTCHours() * 60 + date.getUTCMinutes();
  }
}

function inSleepWindow(midMin: number, sleepStart: number, sleepEnd: number): boolean {
  if (sleepStart === sleepEnd) return false;
  if (sleepStart < sleepEnd) return midMin >= sleepStart && midMin < sleepEnd;
  return midMin >= sleepStart || midMin < sleepEnd; // wraps midnight
}

function windowForHour(hour: number): string {
  if (hour >= 6 && hour < 12) return 'morning';
  if (hour >= 12 && hour < 17) return 'afternoon';
  if (hour >= 17 && hour < 21) return 'evening';
  return 'night';
}

export function hhmmToMinutes(hhmm: string): number {
  const [h, m] = hhmm.split(':').map(Number);
  return (h || 0) * 60 + (m || 0);
}

/**
 * Member is available for a slot when:
 *  - no busy interval overlaps the slot, AND
 *  - the slot's midpoint is not in their sleep window, AND
 *  - the slot's weekday is in their active weekdays (if restricted).
 */
function isAvailable(member: MemberAvailability, slot: Interval): boolean {
  for (const busy of member.intervals) {
    if (slot.start < busy.end && busy.start < slot.end) return false;
  }
  const mid = new Date((slot.start.getTime() + slot.end.getTime()) / 2);
  if (inSleepWindow(localMinutes(mid, member.timezone), member.sleepStartMin, member.sleepEndMin)) {
    return false;
  }
  if (member.weekdays.length > 0) {
    try {
      const wdStr = new Intl.DateTimeFormat('en-US', {
        timeZone: member.timezone,
        weekday: 'short',
      }).format(mid);
      const wd = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].indexOf(wdStr);
      if (!member.weekdays.includes(wd)) return false;
    } catch {
      /* ignore tz errors */
    }
  }
  return true;
}

/**
 * Find ranked common free slots across a set of members (section 15).
 */
export function findFreeSlots(input: SlotFindInput): SlotResult[] {
  const {
    rangeStart,
    rangeEnd,
    durationMinutes,
    members,
    requiredMemberIds,
    minimumAvailableCount,
    preferredTimeWindows = [],
    timezone,
    maxResults = 12,
  } = input;

  const grid = input.gridMinutes ?? STEP;
  const stepMs = grid * 60_000;
  const durationMs = durationMinutes * 60_000;
  const results: SlotResult[] = [];
  const totalCount = members.length;

  if (totalCount === 0 || durationMs <= 0) return [];

  for (let t = rangeStart.getTime(); t + durationMs <= rangeEnd.getTime(); t += stepMs) {
    const slot: Interval = { start: new Date(t), end: new Date(t + durationMs) };
    const available: string[] = [];
    const unavailable: string[] = [];
    let requiredOk = true;

    for (const member of members) {
      if (isAvailable(member, slot)) available.push(member.memberId);
      else {
        unavailable.push(member.memberId);
        if (requiredMemberIds.includes(member.memberId)) requiredOk = false;
      }
    }

    const availableCount = available.length;
    if (!requiredOk) continue;
    if (availableCount < minimumAvailableCount) continue;
    if (availableCount === 0) continue;

    const midHour = localHour(new Date(t + durationMs / 2), timezone);
    const window = windowForHour(midHour);
    const preferred = preferredTimeWindows.includes(window);

    // Weighted score in [0, 1].
    const availabilityRatio = availableCount / totalCount;
    const windowBonus = preferred ? 0.22 : 0;
    const comfortBonus = midHour >= 9 && midHour <= 20 ? 0.08 : -0.08;
    let score = 0.6 * availabilityRatio + windowBonus + comfortBonus;
    score = Math.max(0, Math.min(1, score));

    results.push({
      start: slot.start.toISOString(),
      end: slot.end.toISOString(),
      availableCount,
      totalCount,
      unavailableMemberIds: unavailable,
      score: Number(score.toFixed(3)),
      window,
    });
  }

  results.sort((a, b) => b.score - a.score || b.availableCount - a.availableCount);
  return results.slice(0, maxResults);
}
