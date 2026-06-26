import { Visibility } from '@prisma/client';

/**
 * The privacy-redacted, client-safe representation of a timeline block.
 * The server decides what each viewer may see — the client never gets raw
 * PRIVATE details for blocks it does not own.
 */
export interface BlockView {
  id: string;
  title: string;
  description?: string | null;
  startTime: string;
  endTime: string;
  color: string;
  location?: string | null;
  visibility: Visibility;
  ownerId?: string | null;
  groupId?: string | null;
  createdById: string;
  isEvent: boolean;
  allDay: boolean;
  source: string;
  isOwn: boolean;
  isBusy: boolean;
  redacted: boolean;
  reminderMinutesBefore?: number | null;
}

interface RawBlock {
  id: string;
  title: string;
  description?: string | null;
  startTime: Date;
  endTime: Date;
  color: string;
  location?: string | null;
  visibility: Visibility;
  ownerId?: string | null;
  groupId?: string | null;
  createdById: string;
  isEvent: boolean;
  allDay: boolean;
  source: string;
  reminderMinutesBefore?: number | null;
  /** When set (e.g. via a sync), overrides the block's own visibility. */
  effectiveVisibility?: Visibility;
}

/**
 * Redact a raw block to what `viewerId` is allowed to see.
 * Returns null when the viewer has no access at all (PRIVATE).
 */
export function redactBlock(raw: RawBlock, viewerId: string): BlockView | null {
  const isOwn = raw.ownerId === viewerId || raw.createdById === viewerId;
  const effective = raw.effectiveVisibility ?? raw.visibility;

  // PRIVATE blocks are invisible to anyone who is not the owner/creator.
  if (effective === Visibility.PRIVATE && !isOwn) return null;

  const base = {
    id: raw.id,
    startTime: raw.startTime.toISOString(),
    endTime: raw.endTime.toISOString(),
    color: raw.color,
    visibility: effective,
    ownerId: raw.ownerId ?? null,
    groupId: raw.groupId ?? null,
    createdById: raw.createdById,
    isEvent: raw.isEvent,
    allDay: raw.allDay,
    source: raw.source,
    isOwn,
    reminderMinutesBefore: isOwn ? raw.reminderMinutesBefore ?? null : null,
  };

  if (isOwn || effective === Visibility.FULL) {
    return {
      ...base,
      title: raw.title,
      description: raw.description ?? null,
      location: raw.location ?? null,
      isBusy: false,
      redacted: false,
    };
  }

  if (effective === Visibility.TITLE_ONLY) {
    return {
      ...base,
      title: raw.title,
      description: null,
      location: null,
      isBusy: false,
      redacted: true,
    };
  }

  // BUSY_ONLY
  return {
    ...base,
    title: 'Busy',
    description: null,
    location: null,
    isBusy: true,
    redacted: true,
  };
}
