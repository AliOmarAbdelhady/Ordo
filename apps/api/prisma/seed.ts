import { PrismaClient, GroupRole, GroupType, MemberStatus, Visibility, BlockFlexibility, BlockSource, TaskPriority, TaskStatus, MessageType } from '@prisma/client';
import { hash } from 'bcryptjs';

const prisma = new PrismaClient();

// ── time helpers (UTC, so seed times read naturally with UTC profiles) ────────
const now = new Date();
function at(dayOffset: number, hour: number, minute = 0): Date {
  const d = new Date(now);
  d.setUTCDate(d.getUTCDate() + dayOffset);
  d.setUTCHours(hour, minute, 0, 0);
  return d;
}

async function main() {
  const PASSWORD = await hash('password123', 10);
  // Wipe (dev only) in FK-safe order.
  const models = [
    'reminder', 'notification', 'messageReaction', 'message', 'taskComment',
    'taskAssignee', 'task', 'todo', 'eventAttendee', 'timelineBlockSync',
    'timelineBlock', 'timelineCategory', 'groupInvite', 'groupMember',
    'availabilityPreferences', 'group', 'session', 'user',
  ] as const;
  for (const m of models) await (prisma as any)[m].deleteMany({});

  // ── Users ──────────────────────────────────────────────────────────────────
  const userSpecs = [
    { name: 'Ali Hassan', email: 'ali@ordo.app', username: 'ali', accentColor: 'blue', bio: 'Building things and studying AI.', prefs: { workStart: '09:00', workEnd: '17:00', sleepStart: '23:30', sleepEnd: '07:00', weekdays: [1, 2, 3, 4, 5] } },
    { name: 'Sara Khalid', email: 'sara@ordo.app', username: 'sara', accentColor: 'rose', bio: 'Designer & coffee enthusiast.', prefs: {} },
    { name: 'Omar Faruk', email: 'omar@ordo.app', username: 'omar', accentColor: 'emerald', bio: 'Gym rat. CS student.', prefs: { weekdays: [0, 1, 2, 3, 4, 5, 6] } },
    { name: 'Lina Adel', email: 'lina@ordo.app', username: 'lina', accentColor: 'violet', bio: 'Med student. Plant mom.', prefs: {} },
    { name: 'Yusuf Nabil', email: 'yusuf@ordo.app', username: 'yusuf', accentColor: 'amber', bio: 'Always down for a trip.', prefs: { sleepStart: '01:00', sleepEnd: '09:00' } },
  ];
  const users = await Promise.all(
    userSpecs.map((u) =>
      prisma.user.create({
        data: {
          name: u.name,
          email: u.email,
          username: u.username,
          passwordHash: PASSWORD,
          timezone: 'UTC',
          accentColor: u.accentColor,
          bio: u.bio,
          emailVerified: u.email === 'ali@ordo.app',
          availabilityPrefs: { create: { timezone: 'UTC', ...u.prefs } },
        },
      }),
    ),
  );
  const [ali, sara, omar, lina, yusuf] = users;

  // ── Groups ─────────────────────────────────────────────────────────────────
  const mkSettings = (mods: Record<string, boolean>, defaultVisibility: Visibility) => ({ modules: mods, defaultVisibility });
  const family = await prisma.group.create({
    data: { name: 'Family', type: GroupType.FAMILY, description: 'Home base 🏠', accentColor: 'emerald', createdById: ali.id, settings: mkSettings({ timeline: true, calendar: true, tasks: true, todo: true, chat: true, files: true, location: true, announcements: true, availability: true }, Visibility.TITLE_ONLY), members: { create: [{ userId: ali.id, role: GroupRole.OWNER }, { userId: sara.id, role: GroupRole.ADMIN }, { userId: omar.id }, { userId: lina.id }] } },
  });
  const uni = await prisma.group.create({
    data: { name: 'University', type: GroupType.UNIVERSITY, description: 'CS year 3 🎓', accentColor: 'blue', createdById: ali.id, settings: mkSettings({ timeline: true, calendar: true, tasks: true, files: true, chat: true, announcements: true, availability: true }, Visibility.TITLE_ONLY), members: { create: [{ userId: ali.id, role: GroupRole.OWNER }, { userId: omar.id, role: GroupRole.ADMIN }, { userId: lina.id }, { userId: yusuf.id }] } },
  });
  const friends = await prisma.group.create({
    data: { name: 'Friends', type: GroupType.FRIENDS, description: 'Weekend crew 🎉', accentColor: 'violet', createdById: sara.id, settings: mkSettings({ timeline: true, calendar: true, chat: true, media: true, polls: true, availability: true }, Visibility.TITLE_ONLY), members: { create: [{ userId: sara.id, role: GroupRole.OWNER }, { userId: ali.id, role: GroupRole.ADMIN }, { userId: yusuf.id }] } },
  });

  // ── Ali's self timeline (showcases the privacy/sync feature) ───────────────
  const studyBlock = await prisma.timelineBlock.create({ data: { ownerUserId: ali.id, title: 'Study for AI exam', description: 'Focus: transformers + backprop', startTime: at(0, 17), endTime: at(0, 20), timezone: 'UTC', visibility: Visibility.PRIVATE, color: '#2563EB', source: BlockSource.SELF, createdById: ali.id, reminderMinutesBefore: 30 } });
  const gymBlock = await prisma.timelineBlock.create({ data: { ownerUserId: ali.id, title: 'Gym — Push day', startTime: at(0, 18), endTime: at(0, 19), timezone: 'UTC', visibility: Visibility.PRIVATE, color: '#16A34A', source: BlockSource.SELF, recurrenceRule: 'FREQ=WEEKLY;BYDAY=MO,WE,FR', createdById: ali.id } });
  const doctorBlock = await prisma.timelineBlock.create({ data: { ownerUserId: ali.id, title: 'Doctor appointment', startTime: at(1, 10), endTime: at(1, 11), timezone: 'UTC', visibility: Visibility.PRIVATE, color: '#DC2626', source: BlockSource.SELF, createdById: ali.id, reminderMinutesBefore: 60 } });
  const focusBlock = await prisma.timelineBlock.create({ data: { ownerUserId: ali.id, title: 'Deep work — Ordo features', description: 'Ship timeline sync.', startTime: at(0, 9), endTime: at(0, 12), timezone: 'UTC', visibility: Visibility.TITLE_ONLY, color: '#7C3AED', source: BlockSource.SELF, flexibility: BlockFlexibility.FLEXIBLE, createdById: ali.id } });
  const lunchBlock = await prisma.timelineBlock.create({ data: { ownerUserId: ali.id, title: 'Lunch', startTime: at(0, 12, 30), endTime: at(0, 13, 30), timezone: 'UTC', visibility: Visibility.TITLE_ONLY, color: '#F59E0B', source: BlockSource.SELF, createdById: ali.id } });

  // Syncs: same private block shared with different groups at different visibilities.
  await prisma.timelineBlockSync.createMany({ data: [
    { timelineBlockId: studyBlock.id, groupId: uni.id, visibility: Visibility.FULL, syncedById: ali.id },
    { timelineBlockId: studyBlock.id, groupId: friends.id, visibility: Visibility.BUSY_ONLY, syncedById: ali.id },
    { timelineBlockId: studyBlock.id, groupId: family.id, visibility: Visibility.BUSY_ONLY, syncedById: ali.id },
    { timelineBlockId: doctorBlock.id, groupId: family.id, visibility: Visibility.BUSY_ONLY, syncedById: ali.id },
  ] });

  // ── Group timeline blocks (shared events) ──────────────────────────────────
  await prisma.timelineBlock.create({ data: { groupId: family.id, title: 'Family dinner', description: 'Everyone home by 8!', startTime: at(2, 20), endTime: at(2, 22), timezone: 'UTC', visibility: Visibility.FULL, color: '#16A34A', source: BlockSource.GROUP, isEvent: true, createdById: sara.id, reminderMinutesBefore: 60 } });
  await prisma.timelineBlock.create({ data: { groupId: uni.id, title: 'AI Lecture', startTime: at(1, 9), endTime: at(1, 11), timezone: 'UTC', visibility: Visibility.FULL, color: '#2563EB', source: BlockSource.GROUP, recurrenceRule: 'FREQ=WEEKLY;BYDAY=TU,TH', createdById: omar.id } });
  await prisma.timelineBlock.create({ data: { groupId: uni.id, title: 'Assignment 3 deadline', startTime: at(4, 23), endTime: at(5, 0), timezone: 'UTC', visibility: Visibility.FULL, color: '#DC2626', source: BlockSource.GROUP, isEvent: true, createdById: omar.id } });
  await prisma.timelineBlock.create({ data: { groupId: friends.id, title: 'Movie night', description: 'Voting in chat 🎬', startTime: at(3, 21), endTime: at(3, 23, 30), timezone: 'UTC', visibility: Visibility.FULL, color: '#7C3AED', source: BlockSource.GROUP, isEvent: true, createdById: sara.id } });

  // ── Tasks ──────────────────────────────────────────────────────────────────
  const t1 = await prisma.task.create({ data: { groupId: family.id, createdById: sara.id, title: 'Order the cake for dinner', priority: TaskPriority.HIGH, status: TaskStatus.TODO, dueAt: at(2, 16), assignees: { create: { userId: omar.id } } } });
  await prisma.task.create({ data: { groupId: family.id, createdById: ali.id, title: 'Pick up groceries', priority: TaskPriority.MEDIUM, status: TaskStatus.IN_PROGRESS, dueAt: at(0, 18), assignees: { create: { userId: ali.id } } } });
  await prisma.task.create({ data: { groupId: uni.id, createdById: omar.id, title: 'Upload lecture notes (Week 9)', priority: TaskPriority.HIGH, status: TaskStatus.TODO, dueAt: at(1, 23), assignees: { create: { userId: lina.id } } } });
  await prisma.task.create({ data: { groupId: uni.id, createdById: omar.id, title: 'Prepare presentation slides', priority: TaskPriority.URGENT, status: TaskStatus.TODO, dueAt: at(3, 10), assignees: { create: { userId: ali.id } } } });
  await prisma.task.create({ data: { groupId: friends.id, createdById: sara.id, title: 'Book the cinema tickets', priority: TaskPriority.MEDIUM, status: TaskStatus.TODO, dueAt: at(2, 20), assignees: { create: { userId: yusuf.id } } } });
  await prisma.task.create({ data: { groupId: uni.id, createdById: ali.id, title: 'Review PR #42', priority: TaskPriority.LOW, status: TaskStatus.DONE, assignees: { create: { userId: omar.id } } } });
  await prisma.taskComment.create({ data: { taskId: t1.id, userId: sara.id, body: 'Chocolate, like last time 🍫' } });

  // ── Todos ──────────────────────────────────────────────────────────────────
  const selfTodos = [
    { title: 'Reply to professor', dueAt: at(0, 17), order: 0 },
    { title: 'Buy snacks for movie night', dueAt: at(3, 18), order: 1 },
    { title: 'Renew gym membership', dueAt: null, order: 2 },
    { title: 'Call mom', order: 3 },
  ];
  for (const t of selfTodos) await prisma.todo.create({ data: { ownerUserId: ali.id, createdById: ali.id, title: t.title, dueAt: t.dueAt, order: t.order, labels: t.title.includes('snack') ? ['friends'] : [] } });
  await prisma.todo.create({ data: { groupId: family.id, createdById: sara.id, title: 'Water the plants', dueAt: at(1, 9), order: 0, labels: ['home'] } });

  // ── Chat ───────────────────────────────────────────────────────────────────
  const chat = (groupId: string, senderId: string, body: string, minutesAgo: number) =>
    prisma.message.create({ data: { groupId, senderId, body, type: MessageType.TEXT, createdAt: new Date(now.getTime() - minutesAgo * 60_000) } });
  await chat(family.id, sara.id, 'Dinner this Friday — everyone good with 8?', 240);
  await chat(family.id, omar.id, 'Works for me 👍', 235);
  await chat(family.id, lina.id, 'I will be a little late, save me food!', 230);
  await chat(family.id, ali.id, '@omar can you grab the cake? Added it as a task 🎂', 120);

  await chat(uni.id, omar.id, 'Notes for week 9 are almost ready', 90);
  await chat(uni.id, lina.id, 'Thanks! I can upload them tonight.', 80);
  await chat(uni.id, yusuf.id, 'Anyone free Thursday evening to study together?', 40);

  await chat(friends.id, sara.id, 'Movie night Wednesday! 🎬', 60);
  await chat(friends.id, yusuf.id, 'Yesss, my pick this time', 55);
  await chat(friends.id, ali.id, 'Count me in after 9', 50);

  // ── Notifications for Ali ──────────────────────────────────────────────────
  await prisma.notification.create({ data: { userId: ali.id, type: 'TASK_ASSIGNED', title: 'New task assigned to you', body: 'Prepare presentation slides', data: { groupId: uni.id, taskId: t1.id } } });
  await prisma.notification.create({ data: { userId: ali.id, type: 'MESSAGE_MENTION', title: 'Omar mentioned you', body: '@ali can you grab the cake? Added it as a task 🎂', data: { groupId: family.id } } });

  console.log('✅ Seed complete');
  console.log('   Login: ali@ordo.app  /  password123');
  console.log(`   Users: ${[ali, sara, omar, lina, yusuf].map((u) => u.username).join(', ')}`);
  console.log(`   Groups: ${[family, uni, friends].map((g) => g.name).join(', ')}`);
}

main()
  .then(() => prisma.$disconnect())
  .catch(async (e) => {
    console.error(e);
    await prisma.$disconnect();
    process.exit(1);
  });
