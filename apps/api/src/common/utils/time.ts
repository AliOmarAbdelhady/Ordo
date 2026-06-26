/**
 * Timezone helpers. Backend stores everything as UTC Date objects; the
 * timezone string is metadata used for local-hour scoring (e.g. "evening").
 */

/** Returns the local hour (0-23) of a UTC Date in the given IANA timezone. */
export function localHour(date: Date, timezone: string): number {
  try {
    const hourStr = new Intl.DateTimeFormat('en-US', {
      timeZone: timezone,
      hour: 'numeric',
      hour12: false,
    }).format(date);
    return Number(hourStr) % 24;
  } catch {
    return date.getUTCHours();
  }
}

/** Returns the local weekday 0=Sun..6=Sat of a UTC Date in the timezone. */
export function localWeekday(date: Date, timezone: string): number {
  try {
    const parts = new Intl.DateTimeFormat('en-US', {
      timeZone: timezone,
      weekday: 'short',
    }).format(date);
    return ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].indexOf(parts);
  } catch {
    return date.getUTCDay();
  }
}

/** Local HH:mm in the given timezone (for display). */
export function localTimeLabel(date: Date, timezone: string): string {
  try {
    return new Intl.DateTimeFormat('en-US', {
      timeZone: timezone,
      hour: '2-digit',
      minute: '2-digit',
      hour12: false,
    }).format(date);
  } catch {
    return date.toISOString().slice(11, 16);
  }
}

export interface Interval {
  start: Date;
  end: Date;
}

export function overlaps(a: Interval, b: Interval): boolean {
  return a.start < b.end && b.start < a.end;
}
