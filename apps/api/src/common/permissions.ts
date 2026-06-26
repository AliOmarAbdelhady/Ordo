import { GroupRole } from '@prisma/client';

export type Permission =
  | 'GROUP_UPDATE'
  | 'GROUP_DELETE'
  | 'MEMBER_INVITE'
  | 'MEMBER_REMOVE'
  | 'MEMBER_ROLE_UPDATE'
  | 'TIMELINE_CREATE'
  | 'TIMELINE_UPDATE_ANY'
  | 'EVENT_CREATE'
  | 'TASK_CREATE'
  | 'TASK_ASSIGN'
  | 'TASK_UPDATE_ANY'
  | 'TASK_DELETE_ANY'
  | 'TODO_CREATE'
  | 'CHAT_SEND'
  | 'CHAT_DELETE_ANY'
  | 'FILE_UPLOAD'
  | 'FILE_DELETE_ANY'
  | 'POLL_CREATE'
  | 'POLL_CLOSE_ANY'
  | 'ANNOUNCEMENT_CREATE'
  | 'ANNOUNCEMENT_DELETE_ANY'
  | 'LOCATION_SHARE'
  | 'SETTINGS_UPDATE';

const RANK: Record<GroupRole, number> = {
  GUEST: 0,
  MEMBER: 1,
  MODERATOR: 2,
  ADMIN: 3,
  OWNER: 4,
};

/** Minimum role required to exercise each permission. */
const MIN_ROLE: Record<Permission, GroupRole> = {
  GROUP_UPDATE: 'ADMIN',
  GROUP_DELETE: 'OWNER',
  MEMBER_INVITE: 'MODERATOR',
  MEMBER_REMOVE: 'ADMIN',
  MEMBER_ROLE_UPDATE: 'OWNER',
  TIMELINE_CREATE: 'MEMBER',
  TIMELINE_UPDATE_ANY: 'ADMIN',
  EVENT_CREATE: 'MEMBER',
  TASK_CREATE: 'MEMBER',
  TASK_ASSIGN: 'ADMIN',
  TASK_UPDATE_ANY: 'ADMIN',
  TASK_DELETE_ANY: 'ADMIN',
  TODO_CREATE: 'MEMBER',
  CHAT_SEND: 'MEMBER',
  CHAT_DELETE_ANY: 'ADMIN',
  FILE_UPLOAD: 'MEMBER',
  FILE_DELETE_ANY: 'ADMIN',
  POLL_CREATE: 'MEMBER',
  POLL_CLOSE_ANY: 'ADMIN',
  ANNOUNCEMENT_CREATE: 'ADMIN',
  ANNOUNCEMENT_DELETE_ANY: 'ADMIN',
  LOCATION_SHARE: 'MEMBER',
  SETTINGS_UPDATE: 'ADMIN',
};

export function roleRank(role: GroupRole): number {
  return RANK[role];
}

export function can(role: GroupRole, permission: Permission): boolean {
  return RANK[role] >= RANK[MIN_ROLE[permission]];
}
