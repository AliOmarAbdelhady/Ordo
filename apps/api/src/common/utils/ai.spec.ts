import { parseCommand, extractTasks, AiMember } from './ai';

const NOW = new Date('2026-06-26T12:00:00Z'); // Friday
const MEMBERS: AiMember[] = [
  { id: 'u1', name: 'Omar', username: 'omar' },
  { id: 'u2', name: 'Sara', username: 'sara' },
];

describe('parseCommand', () => {
  it('parses an event with a clock time and default duration', () => {
    const s = parseCommand('Family dinner tomorrow at 8 pm', { now: NOW, groupMembers: MEMBERS });
    expect(s.intent).toBe('CREATE_EVENT');
    expect(s.startTime).toBeDefined();
    expect(s.endTime).toBeDefined();
    // tomorrow at 20:00 UTC (26 + 1 = 27th)
    expect(s.startTime).toContain('20:00:00');
    expect(s.startTime).toContain('27');
    expect(s.durationMinutes).toBe(60);
  });

  it('resolves "next monday" relative to the reference date', () => {
    // NOW is Friday 2026-06-27 (the 27th is Saturday; 26th is Friday).
    const s = parseCommand('Team meeting next monday at 9am', { now: NOW });
    expect(s.intent).toBe('CREATE_EVENT');
    expect(s.startTime).toContain('09:00:00');
  });

  it('parses a custom duration', () => {
    const s = parseCommand('Gym session today at 6pm for 90 minutes', { now: NOW });
    expect(s.intent).toBe('CREATE_EVENT');
    expect(s.durationMinutes).toBe(90);
  });

  it('extracts an assignee by @mention and resolves their id', () => {
    const s = parseCommand('@omar please bring the projector tomorrow', {
      now: NOW,
      groupMembers: MEMBERS,
    });
    expect(s.intent).toBe('CREATE_TASK');
    expect(s.assigneeName).toBe('Omar');
    expect(s.assigneeId).toBe('u1');
    expect(s.dueDate).toBeDefined();
  });

  it('extracts an assignee by name ("Sara should ...")', () => {
    const s = parseCommand('Sara should upload lecture notes', {
      now: NOW,
      groupMembers: MEMBERS,
    });
    expect(s.intent).toBe('CREATE_TASK');
    expect(s.assigneeName).toBe('Sara');
    expect(s.assigneeId).toBe('u2');
  });

  it('treats "remind me to" with no time as a REMINDER', () => {
    const s = parseCommand('remind me to call mom', { now: NOW });
    expect(s.intent).toBe('REMINDER');
    expect(s.title).toContain('call mom');
  });

  it('returns NONE for gibberish', () => {
    const s = parseCommand('asdf qwerty', { now: NOW });
    expect(s.intent).toBe('NONE');
  });

  it('detects a summary request', () => {
    const s = parseCommand('summarize this group', { now: NOW });
    expect(s.intent).toBe('SUMMARY');
  });

  it('never returns undefined critical fields for an event', () => {
    const s = parseCommand('Lunch today at 1pm', { now: NOW });
    expect(s.intent).toBe('CREATE_EVENT');
    expect(typeof s.title).toBe('string');
    expect(s.title.length).toBeGreaterThan(0);
  });

  it('respects 12-hour midnight rollover (12 am)', () => {
    const s = parseCommand('Flight today at 12 am', { now: NOW });
    expect(s.intent).toBe('CREATE_EVENT');
    expect(s.startTime).toContain('00:00:00');
  });

  it('does not hallucinate an assignee for a self event', () => {
    const s = parseCommand('Study session tomorrow at 5pm', { now: NOW, groupMembers: MEMBERS });
    expect(s.intent).toBe('CREATE_EVENT');
    expect(s.assigneeName).toBeUndefined();
  });
});

describe('extractTasks', () => {
  it('pulls actionable items out of a chat message', () => {
    const out = extractTasks('Hey all. Omar please bring snacks tomorrow. Also the weather is nice.', MEMBERS);
    expect(out.length).toBeGreaterThanOrEqual(1);
    const first = out.find((o) => o.assigneeName === 'Omar');
    expect(first).toBeDefined();
    expect(first?.intent).toBe('CREATE_TASK');
  });

  it('ignores non-actionable sentences', () => {
    const out = extractTasks('The sky is blue. I like pizza.', MEMBERS);
    expect(out).toHaveLength(0);
  });
});
