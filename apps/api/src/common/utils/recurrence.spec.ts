import { expandRecurrence } from './recurrence';

const block = (start: string, end: string, recurrenceRule?: string) => ({
  startTime: new Date(start),
  endTime: new Date(end),
  recurrenceRule,
});

describe('expandRecurrence', () => {
  it('returns a single occurrence for a non-recurring block in range', () => {
    const out = expandRecurrence(
      block('2026-06-27T09:00:00Z', '2026-06-27T11:00:00Z'),
      new Date('2026-06-27T00:00:00Z'),
      new Date('2026-06-27T23:59:59Z'),
    );
    expect(out).toHaveLength(1);
    expect(out[0].start.toISOString()).toContain('09:00:00');
  });

  it('returns nothing for a non-recurring block outside the window', () => {
    const out = expandRecurrence(
      block('2026-06-01T09:00:00Z', '2026-06-01T10:00:00Z'),
      new Date('2026-06-27T00:00:00Z'),
      new Date('2026-06-27T23:59:59Z'),
    );
    expect(out).toHaveLength(0);
  });

  it('expands a DAILY rule across a week', () => {
    const out = expandRecurrence(
      block('2026-06-27T07:00:00Z', '2026-06-27T08:00:00Z', 'FREQ=DAILY'),
      new Date('2026-06-27T00:00:00Z'),
      new Date('2026-07-03T23:59:59Z'),
    );
    expect(out.length).toBeGreaterThanOrEqual(7);
    // same wall-clock time each day
    expect(out.every((o) => o.start.getUTCHours() === 7)).toBe(true);
  });

  it('respects BYDAY for a weekday rule', () => {
    const out = expandRecurrence(
      block('2026-06-27T07:00:00Z', '2026-06-27T08:00:00Z', 'FREQ=WEEKLY;BYDAY=MO,WE,FR'),
      new Date('2026-06-27T00:00:00Z'),
      new Date('2026-07-10T23:59:59Z'),
    );
    const days = new Set(out.map((o) => o.start.getUTCDay()));
    // 1=Mon, 3=Wed, 5=Fri
    expect(days.has(1)).toBe(true);
    expect(days.has(3)).toBe(true);
    expect(days.has(5)).toBe(true);
    expect(days.has(0)).toBe(false); // no Sunday
  });

  it('keeps the same duration for every occurrence', () => {
    const out = expandRecurrence(
      block('2026-06-27T07:00:00Z', '2026-06-27T07:45:00Z', 'FREQ=DAILY;COUNT=3'),
      new Date('2026-06-01T00:00:00Z'),
      new Date('2026-12-31T23:59:59Z'),
    );
    expect(out).toHaveLength(3);
    for (const o of out) {
      expect(o.end.getTime() - o.start.getTime()).toBe(45 * 60_000);
    }
  });
});
