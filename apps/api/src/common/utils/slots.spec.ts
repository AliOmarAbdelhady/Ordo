import { findFreeSlots, MemberAvailability } from './slots';

const member = (id: string, busy: [string, string][] = [], overrides: Partial<MemberAvailability> = {}): MemberAvailability => ({
  memberId: id,
  intervals: busy.map(([s, e]) => ({ start: new Date(s), end: new Date(e) })),
  timezone: 'UTC',
  sleepStartMin: 23 * 60,
  sleepEndMin: 7 * 60,
  weekdays: [],
  ...overrides,
});

const range = (start: string, end: string) => ({ rangeStart: new Date(start), rangeEnd: new Date(end) });

describe('findFreeSlots', () => {
  it('returns no slots when duration is zero', () => {
    const out = findFreeSlots({
      ...range('2026-06-27T00:00:00Z', '2026-06-27T23:59:00Z'),
      durationMinutes: 0,
      members: [member('a')],
      requiredMemberIds: [],
      minimumAvailableCount: 1,
      timezone: 'UTC',
    });
    expect(out).toHaveLength(0);
  });

  it('finds a free slot when one member has a midday busy block', () => {
    const out = findFreeSlots({
      ...range('2026-06-27T08:00:00Z', '2026-06-27T20:00:00Z'),
      durationMinutes: 60,
      members: [member('a', [['2026-06-27T12:00:00Z', '2026-06-27T13:00:00Z']])],
      requiredMemberIds: [],
      minimumAvailableCount: 1,
      timezone: 'UTC',
      maxResults: 50,
    });
    // The 12:00–13:00 slot must never appear.
    expect(out.find((s) => s.start.includes('12:00:00'))).toBeUndefined();
    expect(out.length).toBeGreaterThan(0);
  });

  it('excludes slots where a required member is busy', () => {
    const out = findFreeSlots({
      ...range('2026-06-27T08:00:00Z', '2026-06-27T12:00:00Z'),
      durationMinutes: 60,
      members: [
        member('a', [['2026-06-27T08:00:00Z', '2026-06-27T10:00:00Z']]),
        member('b'),
      ],
      requiredMemberIds: ['a'],
      minimumAvailableCount: 1,
      timezone: 'UTC',
      maxResults: 50,
    });
    // 'a' is busy 8–10; no 60-min slot can start before 09:00 without overlapping.
    for (const s of out) {
      const start = new Date(s.start).getUTCHours();
      expect(start).toBeGreaterThanOrEqual(10);
    }
  });

  it('ranks preferred-time windows higher', () => {
    const out = findFreeSlots({
      ...range('2026-06-27T06:00:00Z', '2026-06-27T22:00:00Z'),
      durationMinutes: 60,
      members: [member('a')],
      requiredMemberIds: [],
      minimumAvailableCount: 1,
      timezone: 'UTC',
      preferredTimeWindows: ['evening'],
      maxResults: 50,
    });
    const best = out[0];
    // The best slot's midpoint must land in the preferred evening window.
    expect(best.window).toBe('evening');
  });
});
