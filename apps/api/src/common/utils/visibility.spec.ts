import { Visibility } from '@prisma/client';
import { redactBlock } from './visibility';

const raw = (overrides: Partial<Parameters<typeof redactBlock>[0]> = {}) => ({
  id: 'b1',
  title: 'Doctor appointment',
  description: 'Dr. Smith — cardiology',
  startTime: new Date('2026-06-27T09:00:00Z'),
  endTime: new Date('2026-06-27T10:00:00Z'),
  color: '#2563EB',
  location: 'Clinic',
  visibility: Visibility.BUSY_ONLY,
  ownerId: 'owner-1',
  groupId: null,
  createdById: 'owner-1',
  isEvent: false,
  allDay: false,
  source: 'SELF',
  reminderMinutesBefore: 15,
  ...overrides,
});

describe('redactBlock (timeline privacy)', () => {
  it('returns null for a PRIVATE block the viewer does not own', () => {
    expect(redactBlock(raw({ visibility: Visibility.PRIVATE }), 'someone-else')).toBeNull();
  });

  it('shows full details to the owner regardless of visibility', () => {
    const view = redactBlock(raw({ visibility: Visibility.PRIVATE }), 'owner-1');
    expect(view).not.toBeNull();
    expect(view?.title).toBe('Doctor appointment');
    expect(view?.description).toBe('Dr. Smith — cardiology');
    expect(view?.location).toBe('Clinic');
    expect(view?.isOwn).toBe(true);
    expect(view?.redacted).toBe(false);
  });

  it('masks a BUSY_ONLY block as "Busy" for other viewers', () => {
    const view = redactBlock(raw({ visibility: Visibility.BUSY_ONLY }), 'someone-else');
    expect(view?.title).toBe('Busy');
    expect(view?.description).toBeNull();
    expect(view?.location).toBeNull();
    expect(view?.isBusy).toBe(true);
    expect(view?.redacted).toBe(true);
    // reminder is private to the owner
    expect(view?.reminderMinutesBefore).toBeNull();
  });

  it('shows the title but hides details for TITLE_ONLY', () => {
    const view = redactBlock(raw({ visibility: Visibility.TITLE_ONLY }), 'someone-else');
    expect(view?.title).toBe('Doctor appointment');
    expect(view?.description).toBeNull();
    expect(view?.location).toBeNull();
    expect(view?.redacted).toBe(true);
  });

  it('shows everything for FULL', () => {
    const view = redactBlock(raw({ visibility: Visibility.FULL }), 'someone-else');
    expect(view?.title).toBe('Doctor appointment');
    expect(view?.description).toBe('Dr. Smith — cardiology');
    expect(view?.redacted).toBe(false);
  });

  it('respects an effective visibility coming from a sync', () => {
    // Owner synced a FULL block into a group at BUSY_ONLY.
    const view = redactBlock(raw({ visibility: Visibility.FULL, effectiveVisibility: Visibility.BUSY_ONLY }), 'someone-else');
    expect(view?.title).toBe('Busy');
  });
});
