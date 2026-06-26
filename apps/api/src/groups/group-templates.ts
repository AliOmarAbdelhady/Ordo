import { GroupType } from '@prisma/client';

export interface GroupModules {
  timeline: boolean;
  calendar: boolean;
  tasks: boolean;
  todo: boolean;
  chat: boolean;
  files: boolean;
  location: boolean;
  members: boolean;
  announcements: boolean;
  polls: boolean;
  media: boolean;
  availability: boolean;
}

export const ALL_MODULES_OFF: GroupModules = {
  timeline: false,
  calendar: false,
  tasks: false,
  todo: false,
  chat: false,
  files: false,
  location: false,
  members: true,
  announcements: false,
  polls: false,
  media: false,
  availability: false,
};

export interface GroupTemplate {
  type: GroupType;
  name: string;
  description: string;
  emoji: string;
  accentColor: string;
  modules: GroupModules;
  defaultVisibility: 'BUSY_ONLY' | 'TITLE_ONLY' | 'FULL';
}

export const GROUP_TEMPLATES: GroupTemplate[] = [
  {
    type: 'FAMILY',
    name: 'Family',
    description: 'Shared family calendar, tasks, reminders and optional location.',
    emoji: '🏠',
    accentColor: 'emerald',
    modules: { ...ALL_MODULES_OFF, timeline: true, calendar: true, tasks: true, todo: true, chat: true, files: true, location: true, announcements: true, availability: true },
    defaultVisibility: 'TITLE_ONLY',
  },
  {
    type: 'UNIVERSITY',
    name: 'University',
    description: 'Class schedules, assignments, files and announcements.',
    emoji: '🎓',
    accentColor: 'blue',
    modules: { ...ALL_MODULES_OFF, timeline: true, calendar: true, tasks: true, files: true, chat: true, announcements: true, availability: true },
    defaultVisibility: 'TITLE_ONLY',
  },
  {
    type: 'GYM',
    name: 'Gym / Sports',
    description: 'Training schedule, attendance, tasks and media.',
    emoji: '💪',
    accentColor: 'orange',
    modules: { ...ALL_MODULES_OFF, timeline: true, tasks: true, chat: true, media: true, location: true, availability: true },
    defaultVisibility: 'BUSY_ONLY',
  },
  {
    type: 'FRIENDS',
    name: 'Friends',
    description: 'Plan outings, find free time, share media and run polls.',
    emoji: '🎉',
    accentColor: 'violet',
    modules: { ...ALL_MODULES_OFF, timeline: true, calendar: true, chat: true, media: true, polls: true, availability: true },
    defaultVisibility: 'TITLE_ONLY',
  },
  {
    type: 'WORK',
    name: 'Work',
    description: 'Projects, tasks, files and focused coordination.',
    emoji: '💼',
    accentColor: 'slate',
    modules: { ...ALL_MODULES_OFF, timeline: true, tasks: true, todo: true, files: true, chat: true, announcements: true, availability: true },
    defaultVisibility: 'BUSY_ONLY',
  },
  {
    type: 'PROJECT',
    name: 'Project',
    description: 'Lightweight project tracking with tasks and timeline.',
    emoji: '🚀',
    accentColor: 'cyan',
    modules: { ...ALL_MODULES_OFF, timeline: true, tasks: true, todo: true, files: true, chat: true },
    defaultVisibility: 'FULL',
  },
  {
    type: 'TRAVEL',
    name: 'Travel',
    description: 'Itinerary, shared timeline, polls and media.',
    emoji: '✈️',
    accentColor: 'amber',
    modules: { ...ALL_MODULES_OFF, timeline: true, calendar: true, chat: true, media: true, polls: true, location: true },
    defaultVisibility: 'FULL',
  },
  {
    type: 'CUSTOM',
    name: 'Custom',
    description: 'Start from a blank space and choose your modules.',
    emoji: '✨',
    accentColor: 'blue',
    modules: { ...ALL_MODULES_OFF, timeline: true, tasks: true, chat: true },
    defaultVisibility: 'TITLE_ONLY',
  },
];

export function templateFor(type: GroupType): GroupTemplate {
  return GROUP_TEMPLATES.find((t) => t.type === type) ?? GROUP_TEMPLATES[GROUP_TEMPLATES.length - 1];
}

export const GROUP_TYPES = GROUP_TEMPLATES.map((t) => ({
  type: t.type,
  name: t.name,
  emoji: t.emoji,
  description: t.description,
  accentColor: t.accentColor,
}));
