# Ordo — Full Product, UX, Architecture, and Implementation Plan

**Version:** 1.0  
**Date:** 2026-06-26  
**Target reader:** Product owner, Flutter developer, NestJS backend developer, UI designer, and AI coding agent such as Claude Opus 4.8.  
**Internal project name:** Ordo  
**Public-name warning:** The name should be checked before launch because existing apps already use similar names. Keep “Ordo” as the working name until trademark, domain, App Store, and Google Play checks are complete.

---

## 0. Source foundation and technology references

This plan is based on the current product idea plus official technology references:

- Flutter is suitable for a mobile-first cross-platform application because it supports building mobile, web, desktop, and embedded apps from a single codebase: <https://flutter.dev/>
- Flutter supports Material 3 design and app-wide theming: <https://m3.material.io/develop/flutter> and <https://docs.flutter.dev/cookbook/design/themes>
- Flutter navigation can use Router/Navigator and declarative routing packages such as `go_router`: <https://docs.flutter.dev/ui/navigation>
- Riverpod is a strong Flutter state-management option with DevTools visibility: <https://riverpod.dev/>
- NestJS is suitable for the backend because it is a TypeScript framework for efficient, scalable Node.js server-side applications: <https://docs.nestjs.com/> and <https://nestjs.com/>
- NestJS supports WebSocket gateways and Socket.IO/ws adapters for realtime functionality: <https://docs.nestjs.com/websockets/gateways>
- PostgreSQL is a mature open-source object-relational database with a strong reputation for reliability and robustness: <https://www.postgresql.org/>
- PostgreSQL supports JSON/JSONB for flexible settings/configuration data: <https://www.postgresql.org/docs/current/datatype-json.html>
- Prisma is an open-source ORM for Node.js/TypeScript and has an official NestJS recipe: <https://docs.nestjs.com/recipes/prisma> and <https://www.prisma.io/docs/guides/frameworks/nestjs>
- PostGIS extends PostgreSQL with geospatial storage, indexing, and querying: <https://postgis.net/>
- Redis Pub/Sub supports realtime channel messaging patterns: <https://redis.io/docs/latest/develop/pubsub/>
- BullMQ is a Redis-backed Node.js queue system for background jobs: <https://docs.bullmq.io/>
- Firebase Cloud Messaging is a cross-platform messaging solution for reliable push notifications: <https://firebase.google.com/docs/cloud-messaging>
- Apple Push Notification service is used for remote notifications on Apple platforms: <https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns>
- Google Calendar API Freebusy returns free/busy information for calendars: <https://developers.google.com/workspace/calendar/api/v3/reference/freebusy>
- Google Calendar API reference includes resources such as Events, CalendarList, Settings, and Freebusy: <https://developers.google.com/workspace/calendar/api/v3/reference>
- OAuth PKCE is defined in RFC 7636 and should be used for public/mobile OAuth flows: <https://datatracker.ietf.org/doc/html/rfc7636>
- OWASP API Security Top 10 highlights API risks such as broken object-level authorization: <https://owasp.org/API-Security/editions/2023/en/0x11-t10/>
- OpenAI Structured Outputs and Claude Structured Outputs support JSON-schema-constrained AI output: <https://developers.openai.com/api/docs/guides/structured-outputs> and <https://platform.claude.com/docs/en/build-with-claude/structured-outputs>
- Claude Opus 4.8 is described by Anthropic as suitable for complex reasoning and long-horizon agentic coding: <https://platform.claude.com/docs/en/about-claude/models/overview>

---

## 1. Product definition

### 1.1 One-sentence definition

**Ordo is a time-first group coordination app that helps people organize daily, weekly, and monthly life with themselves and their groups through shared timelines, availability, tasks, reminders, chat, files, calendar sync, and privacy-controlled presence.**

### 1.2 What Ordo is not

Ordo is **not** a WhatsApp clone. Chat exists, but chat is not the core product. The core product is:

1. Personal timeline.
2. Group timeline.
3. Shared availability.
4. Tasks and reminders attached to time.
5. Privacy-controlled synchronization between personal life and group life.

### 1.3 Product positioning

The strongest positioning:

> **Ordo is a shared life operating system for groups.**

It combines:

- Calendar planning.
- Group chat.
- To-do lists.
- Admin-assigned tasks.
- Timeline visibility.
- Empty-slot discovery.
- Optional location sharing.
- AI-assisted scheduling and summarization.

### 1.4 Core product promise

Users should feel:

> “I can organize my day, week, and month with myself and my groups without searching through messages or asking everyone when they are free.”

---

## 2. Product principles

### 2.1 Time-first, chat-second

Every major object should connect to time when appropriate:

- Timeline block.
- Task.
- To-do item.
- Reminder.
- Event.
- Chat message.
- File.
- Location share.

Chat should support coordination, not replace structured coordination.

### 2.2 Privacy by default

A user’s private timeline may say:

> “Doctor appointment.”

But the group should see only:

> “Busy.”

Unless the user explicitly shares details.

### 2.3 Two-tap rule

The most frequent actions should take at most two taps:

- Add timeline block.
- Add task.
- Find common free slot.
- Open group timeline.
- Open group chat.
- Mark task complete.
- Turn location sharing on/off.

### 2.4 Progressive complexity

Beginners should see a simple app. Advanced users should be able to customize deeply.

Default UX should be simple. Advanced settings should be hidden under group settings and profile settings.

### 2.5 Groups are spaces, not just chats

Each group is a structured space:

```text
Group
  Home
  Timeline
  Calendar
  Tasks
  To-do
  Chat
  Files
  Members
  Location
  Settings
```

### 2.6 Self group / personal space

Every user has a private “Self” space. This is not a normal group with other members. It is the user’s personal life organizer.

The Self space contains:

- Daily timeline.
- Weekly timeline.
- Monthly timeline.
- Personal tasks.
- Personal to-dos.
- Personal calendar.
- Personal reminders.
- AI planning assistant.

---

## 3. Main user personas

### 3.1 Student

Needs:

- University group schedules.
- Assignment tasks.
- Study timeline.
- File sharing.
- Empty-slot finder for group study.

### 3.2 Family organizer

Needs:

- Shared family calendar.
- Shopping tasks.
- Reminders.
- Optional location sharing.
- Private timeline visibility.

### 3.3 Sports/gym group admin

Needs:

- Training schedule.
- Attendance reminders.
- Task assignments.
- Media uploads.
- Finding the best time for sessions.

### 3.4 Friend group

Needs:

- Plan outings.
- Find free time.
- Share media.
- Chat.
- Polls and reminders.

### 3.5 Busy professional

Needs:

- Personal timeline.
- Google Calendar integration.
- Busy-only sharing with groups.
- AI summarization.
- Conflict alerts.

---

## 4. Core concepts and domain model

### 4.1 Spaces

There are two kinds of spaces:

1. **Self Space**: the user’s private personal organizer.
2. **Group Space**: a shared group with members, roles, timeline, tasks, chat, and settings.

### 4.2 Timeline scopes

A timeline can exist in:

- Self Space.
- Family group.
- Gym group.
- University group.
- Friends group.
- Any custom group.

### 4.3 Timeline views

Each space supports:

1. **Daily timeline** — detailed schedule for one day.
2. **Weekly timeline** — overview of the week.
3. **Monthly timeline** — higher-level planning, events, and milestones.

### 4.4 Timeline block

A timeline block is a period of time.

Examples:

```text
9:00 AM – 11:00 AM: Study database
6:00 PM – 7:00 PM: Gym
Friday 8:00 PM – 10:00 PM: Family dinner
```

A timeline block has:

- Title.
- Description.
- Start time.
- End time.
- Space owner: Self or group.
- Visibility.
- Color/category.
- Optional recurrence.
- Optional reminders.
- Optional linked tasks/files/messages.

### 4.5 Timeline visibility levels

Recommended visibility levels:

```text
PRIVATE       Only me.
BUSY_ONLY     Others see “Busy”.
TITLE_ONLY    Others see title only.
FULL          Others see title, description, location, attachments.
```

### 4.6 Timeline sync

A user creates a timeline block in Self Space and can sync it to selected groups.

Example:

```text
Self timeline block:
  Title: Study for AI exam
  Time: 5 PM – 8 PM

Sync to:
  Family group: Busy only
  Friends group: Busy only
  University group: Full details
```

This is one of the most important privacy features.

### 4.7 Group timeline types

A group can have:

- Shared group events.
- Member busy overlays.
- Admin-created timeline blocks.
- Member-created timeline blocks, depending on permissions.
- Suggested time slots.

### 4.8 Availability

Availability is calculated from:

- Self timeline.
- Group timeline.
- Synced busy blocks.
- Google Calendar busy blocks.
- Manual availability preferences.
- Timezone.
- Optional sleep/work/study preferences.

### 4.9 Tasks vs to-dos

Use separate concepts:

#### To-do

A simple item that may or may not have a due date.

Examples:

- Buy snacks.
- Bring football.
- Prepare presentation.

#### Task

A structured assignable work item.

Examples:

- Admin assigns Omar to bring water.
- Admin assigns Sara to upload lecture notes.
- User assigns himself to finish report by Monday.

Tasks have assignees, status, priority, comments, files, and audit history.

---

## 5. Feature inventory

### 5.1 Authentication

Must support:

- Register with phone number.
- Register with email.
- Login with email/password.
- Login with phone OTP.
- Optional Google login.
- Optional Apple login for iOS.
- Device session management.
- Password reset.
- Email verification.
- Phone verification.
- Account deletion.
- Export data.

Recommended security:

- Argon2 or bcrypt password hashing.
- Short-lived access tokens.
- Long-lived refresh tokens stored securely.
- Refresh-token rotation.
- Device/session revocation.
- Rate limiting OTP attempts.
- CAPTCHA or abuse protection after repeated failed attempts.
- OAuth PKCE for mobile OAuth flows.

### 5.2 User profile

Profile fields:

- Display name.
- Username / handle.
- Avatar.
- Phone.
- Email.
- Bio.
- Timezone.
- Theme preference.
- Notification preferences.
- Privacy preferences.
- Calendar integrations.
- Location-sharing preferences.

### 5.3 Group creation

Create group flow:

1. Choose group type.
2. Add group name.
3. Add avatar.
4. Choose modules.
5. Invite members.
6. Set privacy defaults.
7. Finish.

Group types:

- Family.
- Friends.
- University.
- Gym.
- Sports.
- Work.
- Project.
- Travel.
- Custom.

### 5.4 Group customization

Admin can customize:

- Group name.
- Group avatar.
- Theme/accent.
- Enabled modules.
- Member permissions.
- Timeline visibility defaults.
- Task assignment rules.
- Location sharing rules.
- File upload limits.
- Reminder defaults.
- Announcement permissions.

### 5.5 Timeline system

Must support:

- Daily timeline.
- Weekly timeline.
- Monthly timeline.
- Self timeline.
- Group timeline.
- Add/edit/delete block.
- Drag and resize blocks.
- Recurring blocks.
- Category colors.
- Conflict detection.
- Sync block to selected groups.
- Visibility per group.
- Timeline templates.
- Timeline search.
- Timeline filters.

### 5.6 Calendar system

Must support:

- Group calendar.
- Self calendar.
- Event creation.
- Event invitations.
- RSVP: going, maybe, not going.
- Calendar month view.
- Calendar week view.
- Calendar agenda view.
- Google Calendar integration.
- Import external busy blocks.
- Export Ordo events.
- Free/busy lookup.
- Calendar conflict warning.

### 5.7 Empty-slot finder

Inputs:

- Group.
- Date range.
- Duration.
- Required members.
- Optional members.
- Preferred time of day.
- Minimum attendance threshold.
- Location preference.

Outputs:

- Ranked free slots.
- Number of available members.
- Members unavailable.
- Conflict reasons, if visible.
- Button to create event.
- Button to poll members.

### 5.8 To-do list

Must support:

- Group to-do.
- Self to-do.
- Due date optional.
- Due time optional.
- No date/time allowed.
- Labels.
- Checklist items.
- Reordering.
- Comments.
- Attachments.
- Reminder optional.

### 5.9 Tasks

Must support:

- Admin-assigned tasks.
- Self-assigned tasks.
- Multiple assignees.
- Status.
- Priority.
- Due date/time optional.
- Reminder.
- Comments.
- Files.
- Task history.
- Task templates.
- Subtasks.

Task statuses:

```text
TODO
IN_PROGRESS
BLOCKED
DONE
CANCELLED
```

### 5.10 Chat

Must support:

- Group chat.
- Message replies.
- Mentions.
- Reactions.
- Attachments.
- Pinned messages.
- Announcements.
- Search.
- Message edit/delete.
- Read receipts, optional by group.
- Link a message to task/event.

### 5.11 Inbox / private communication

Must support:

- Direct messages.
- Private member threads.
- Admin-to-member messages.
- Task-related private discussion.
- Optional private group subthreads.

### 5.12 Media and files

Must support:

- Images.
- Videos.
- PDFs.
- Documents.
- Audio.
- Archives, if allowed.
- File previews.
- Thumbnails.
- Folder/tag organization.
- Search by filename.
- File linked to task/event/message.

Security requirements:

- Store files in S3-compatible object storage.
- Use signed URLs.
- Validate MIME type.
- Limit file size.
- Virus/malware scan in production.
- Do not expose public bucket URLs by default.

### 5.13 Location

Must support:

- Opt-in only.
- Group-specific permission.
- Temporary sharing.
- Precise or approximate mode.
- Manual on/off.
- Visible indicator when sharing.
- Location history disabled by default.
- Optional expiry.
- Admin cannot force a member to share location.

Location modes:

```text
OFF
APPROXIMATE
PRECISE_TEMPORARY
PRECISE_ALWAYS_WHILE_ENABLED
```

### 5.14 Reminders and notifications

Reminder targets:

- Timeline blocks.
- Group events.
- Tasks.
- To-dos.
- Files needing review.
- Location arrival/departure, future feature.
- Calendar conflicts.

Notification channels:

- Push notification.
- In-app notification.
- Email, optional.
- SMS, optional and paid.

### 5.15 Search

Global search should find:

- Groups.
- Members.
- Timeline blocks.
- Events.
- Tasks.
- To-dos.
- Messages.
- Files.

MVP search can use PostgreSQL full-text search. Later add Meilisearch/OpenSearch.

### 5.16 AI assistant

AI features:

- Natural language timeline creation.
- Natural language task creation.
- Empty-slot suggestion.
- Daily plan summary.
- Weekly plan summary.
- Monthly plan summary.
- Group chat summary.
- Task extraction from messages.
- Conflict explanation.
- Smart reminder suggestions.
- “What changed?” group digest.

AI must produce structured JSON before taking action. Important actions require user confirmation.

---

## 6. UX structure — page by page

## 6.1 Splash screen

Purpose:

- Show brand.
- Check auth state.
- Load theme.
- Check secure storage.

UI:

- Minimal logo.
- Blue/white or dark gradient.
- Smooth fade animation.

States:

- Loading.
- Logged out.
- Logged in.
- Offline cached mode.

---

## 6.2 Welcome / landing screen

Purpose:

- Explain Ordo in one screen.

Copy:

```text
Organize life with yourself and your groups.
Timelines, tasks, reminders, chat, and shared availability — in one place.
```

Buttons:

- Create account.
- Log in.

Visual:

- Animated timeline card.
- Floating group avatars.
- Empty-slot suggestion chip.

---

## 6.3 Register screen

Fields:

- Name.
- Email.
- Phone.
- Password.

Options:

- Continue with Google.
- Continue with Apple on iOS.

UX details:

- Inline validation.
- Password strength meter.
- Country code selector.
- Terms and privacy checkbox.

---

## 6.4 OTP verification screen

Purpose:

- Verify phone or email.

UX:

- Six-digit OTP input.
- Auto-fill support.
- Resend timer.
- Change phone/email.

Security:

- Rate limiting.
- Lockout after repeated attempts.

---

## 6.5 Onboarding flow

Step 1: Choose use cases.

```text
Family
University
Gym
Friends
Work
Personal planning
```

Step 2: Set timezone and working/sleeping hours.

Step 3: Create first timeline block.

Step 4: Create first group or skip.

Step 5: Notification permission.

Step 6: Optional Google Calendar connect.

Important: Do not force Google Calendar during onboarding. Make it optional.

---

## 6.6 Main shell

Main navigation tabs:

```text
Today
Groups
Timeline
Inbox
Profile
```

Why this structure:

- Today = daily command center.
- Groups = shared spaces.
- Timeline = personal planning.
- Inbox = private communication.
- Profile = settings and identity.

Floating action button:

```text
+
  Timeline block
  Event
  Task
  To-do
  Reminder
  Upload file
  Find free slot
```

---

## 6.7 Today page

Purpose:

- The user’s daily dashboard.

Sections:

1. Greeting.
2. Current time/status.
3. Today timeline preview.
4. Upcoming group events.
5. Tasks due today.
6. Reminders.
7. AI suggestions.
8. Conflicts.

Example UI:

```text
Good evening, Ali
You are free until 6:00 PM.

Today
[9:00] Study
[12:00] Lunch
[6:00] Gym group session

Suggested
Family group is free at 8:30 PM.
2 tasks need confirmation.
```

Actions:

- Add block.
- Find free time.
- Open full timeline.
- Mark tasks done.

---

## 6.8 Groups page

Purpose:

- Show all user groups.

Sections:

- Pinned groups.
- Recent groups.
- Group invitations.
- Create group.

Group card shows:

- Avatar.
- Group name.
- Type.
- Next event.
- Pending tasks.
- Unread messages.
- Availability alert.

Group card example:

```text
Family
Next: Dinner planning today 8 PM
3 tasks · 2 unread
```

---

## 6.9 Create group page

Steps:

1. Choose template.
2. Add name/avatar.
3. Choose modules.
4. Invite members.
5. Set default privacy.
6. Finish.

Templates:

### Family template

Enabled by default:

- Timeline.
- Calendar.
- Tasks.
- To-do.
- Chat.
- Location.
- Reminders.

### University template

Enabled by default:

- Timeline.
- Calendar.
- Tasks.
- Files.
- Chat.
- Announcements.

### Gym/sports template

Enabled by default:

- Timeline.
- Attendance.
- Tasks.
- Media.
- Chat.
- Location optional.

### Friends template

Enabled by default:

- Timeline.
- Empty-slot finder.
- Events.
- Chat.
- Media.
- Polls.

---

## 6.10 Group home page

Purpose:

- Show one group’s command center.

Header:

- Group avatar.
- Name.
- Member avatars.
- Admin/settings button.

Main cards:

1. Next event.
2. Best free slot.
3. Pending tasks.
4. Recent chat.
5. Recent files.
6. Location status, if enabled.

Module tabs:

```text
Home | Timeline | Calendar | Tasks | Chat | Files | Members
```

If location enabled:

```text
Home | Timeline | Calendar | Tasks | Chat | Files | Location | Members
```

---

## 6.11 Self timeline page

Views:

```text
Day | Week | Month
```

Day view:

- Vertical timeline.
- Current-time indicator.
- Blocks are draggable.
- Pinch/zoom optional later.

Week view:

- Seven columns.
- Blocks compressed.
- Conflict badges.
- Group color overlays.

Month view:

- Calendar grid.
- Dots/chips for major blocks.
- Monthly goals.
- Upcoming deadlines.

Actions:

- Add block.
- Add recurring block.
- Sync with groups.
- Find personal free time.
- Ask AI to plan day/week/month.

---

## 6.12 Group timeline page

Views:

```text
Day | Week | Month | Members
```

Day view:

- Shared group events.
- Busy overlays.
- Member availability strip.

Week view:

- Group events across the week.
- Member conflicts.
- Suggested slots.

Month view:

- High-level group plan.
- Events, deadlines, milestones.

Members view:

- Row per member.
- Busy/free blocks.
- Details hidden unless allowed.

Privacy display:

```text
Ali: Busy
Sara: Available
Omar: Busy until 7 PM
```

Do not reveal private titles unless user allowed it.

---

## 6.13 Add timeline block page/sheet

Use a bottom sheet, not a full page, for speed.

Fields:

- Title.
- Start date/time.
- End date/time.
- Repeat.
- Category.
- Space: Self or group.
- Visibility.
- Sync with groups.
- Reminder.
- Notes.

Fast creation mode:

```text
Title: Study
Today 5 PM – 7 PM
Visibility: Private
[Save]
```

Advanced mode:

- Recurrence.
- Attach task.
- Attach file.
- Location.
- AI optimize.

---

## 6.14 Sync timeline screen

Purpose:

- Let user choose which groups see a personal timeline block.

UI:

```text
Sync “Study for AI exam”

[ ] Family       Busy only
[ ] Friends      Busy only
[ ] University   Full details
[ ] Gym          Do not sync
```

Visibility selector per group:

```text
Private / Busy only / Title only / Full
```

---

## 6.15 Empty-slot finder page

Inputs:

- Group.
- Date range.
- Duration.
- Required members.
- Optional members.
- Preferred time.
- Minimum attendance.

Results:

```text
Best slots
1. Sat 6:00–8:00 PM — 8/9 available
2. Fri 7:00–9:00 PM — 7/9 available
3. Sun 5:00–7:00 PM — 6/9 available
```

Actions:

- Create event.
- Create poll.
- Ask unavailable members.
- Save suggestion.

---

## 6.16 Calendar page

Views:

```text
Agenda | Week | Month
```

Features:

- Self/group switcher.
- Event cards.
- Google Calendar busy overlay.
- Export Ordo event to Google.
- Conflict warning.

---

## 6.17 Tasks page

Tabs:

```text
All | Mine | Assigned by me | Late | Done
```

Task card:

- Title.
- Assignee.
- Due date.
- Priority.
- Status.
- Group.

Actions:

- Create task.
- Assign member.
- Mark done.
- Add reminder.
- Add comment.

---

## 6.18 Task detail page

Sections:

- Title/status.
- Assignee.
- Due date.
- Description.
- Checklist/subtasks.
- Files.
- Comments.
- Activity log.
- Reminder.

Admin actions:

- Reassign.
- Change due date.
- Change priority.
- Delete.

---

## 6.19 To-do page

Tabs:

```text
Today | Upcoming | No date | Done
```

UX:

- Fast add field.
- Drag reorder.
- Optional due date.
- Optional reminder.
- Convert to task.

---

## 6.20 Chat page

Features:

- Group messages.
- Reply.
- React.
- Mention.
- Attach file.
- Create task from message.
- Create event from message.
- Pin message.
- Search.
- AI summarize.

Important UX:

When a message looks like a task, show a small suggestion:

```text
Create task: “Bring projector tomorrow”
```

---

## 6.21 Inbox page

Sections:

- Direct messages.
- Admin messages.
- Task threads.
- Private member conversations.

Thread card:

- Avatar.
- Name.
- Last message.
- Related group.
- Unread count.

---

## 6.22 Files page

Views:

```text
Recent | Images | Videos | Docs | Links
```

Features:

- Upload.
- Preview.
- Download/open.
- Link to task/event.
- Search.
- Sort.
- Filter by uploader.

---

## 6.23 Members page

Shows:

- Members.
- Roles.
- Availability status.
- Location status, if enabled.
- Last active, optional.

Admin actions:

- Invite.
- Change role.
- Remove.
- Modify permissions.

---

## 6.24 Location page

Only available if enabled by group and accepted by user.

Features:

- Map.
- Member cards.
- Sharing status.
- Turn off button.
- Expiry time.
- Approximate/precise switch.

UX warning:

Always display:

```text
Your location is visible to this group.
```

---

## 6.25 Group settings page

Sections:

- General.
- Modules.
- Theme.
- Members and roles.
- Timeline privacy.
- Task permissions.
- Location sharing.
- Notifications.
- Files.
- Danger zone.

---

## 6.26 Profile page

Sections:

- Profile card.
- My timeline.
- My tasks.
- Calendar integrations.
- Themes.
- Privacy.
- Notifications.
- Devices/sessions.
- Data export/delete.

---

## 6.27 AI assistant page

Name suggestion:

```text
Ordo Copilot
```

Capabilities:

- Plan my day.
- Plan my week.
- Plan this group’s month.
- Find time for us.
- Summarize group.
- Extract tasks.
- Explain conflicts.

Important UX:

AI should show a review card before applying changes.

Example:

```text
I found 3 changes:
1. Create event: Gym session, Monday 7 PM.
2. Assign task: Omar brings water.
3. Reminder: 1 hour before.

[Apply] [Edit] [Cancel]
```

---

## 7. Flutter UI system — shadcn/Tailwind/Framer-inspired

Flutter cannot directly use shadcn, Tailwind CSS, or Framer Motion because those are web/React ecosystem tools. But Ordo can imitate their design language through a custom Flutter design system.

### 7.1 Visual target

The UI should feel like:

- shadcn: clean cards, strong typography, tasteful borders, command menus, sheets, tabs, badges.
- Tailwind: consistent spacing scale, color tokens, radius tokens, utility-like design rules.
- Framer Motion: smooth transitions, spring-like movement, gentle layout animations.

### 7.2 Design tokens

Create a design token file:

```dart
class OrdoSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

class OrdoRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const pill = 999.0;
}
```

### 7.3 Color system

Default light theme:

```text
Background:       #F8FAFC
Surface:          #FFFFFF
Primary:          #2563EB
Primary Soft:     #DBEAFE
Text Main:        #0F172A
Text Muted:       #64748B
Border:           #E2E8F0
Success:          #16A34A
Warning:          #F59E0B
Danger:           #DC2626
```

Default dark theme:

```text
Background:       #020617
Surface:          #0F172A
Surface Soft:     #111827
Primary:          #60A5FA
Primary Soft:     #1E3A8A
Text Main:        #F8FAFC
Text Muted:       #94A3B8
Border:           #1E293B
Success:          #22C55E
Warning:          #FBBF24
Danger:           #F87171
```

Optional themes:

- Ocean Blue.
- Midnight Dark.
- Minimal White.
- Purple Neon.
- Emerald Calm.
- Rose Soft.

### 7.4 Typography

Recommended fonts:

- Inter.
- SF Pro-like fallback.
- Arabic support later: Cairo, IBM Plex Sans Arabic, or Noto Sans Arabic.

Text scale:

```text
Display: 32/40 bold
Title 1: 24/32 semibold
Title 2: 20/28 semibold
Body: 16/24 regular
Small: 14/20 regular
Caption: 12/16 medium
```

### 7.5 Components

Create custom reusable Flutter components:

```text
OrdoButton
OrdoIconButton
OrdoInput
OrdoSearchInput
OrdoCard
OrdoGlassCard
OrdoSheet
OrdoDialog
OrdoTabs
OrdoBadge
OrdoAvatar
OrdoAvatarStack
OrdoTimelineBlock
OrdoCalendarCell
OrdoTaskCard
OrdoGroupCard
OrdoCommandMenu
OrdoEmptyState
OrdoLoadingSkeleton
OrdoSegmentedControl
OrdoPermissionSwitch
```

### 7.6 Motion system

Use:

- `AnimatedContainer`.
- `AnimatedOpacity`.
- `TweenAnimationBuilder`.
- `Hero` transitions.
- `PageRouteBuilder`.
- Optional: Rive or Lottie for empty states/onboarding.

Motion rules:

```text
Fast interaction: 120–180ms
Normal transition: 220–300ms
Large page transition: 350–450ms
Avoid excessive animation in productivity screens
```

### 7.7 UI quality checklist

Every screen must have:

- Clear title.
- Obvious primary action.
- Empty state.
- Loading state.
- Error state.
- Offline state where relevant.
- Accessible contrast.
- Support for large text.
- Pull-to-refresh where useful.
- Skeleton loading instead of blank loading.

---

## 8. Recommended technology stack

### 8.1 Mobile app

```text
Flutter
Dart
Riverpod
go_router
Dio
Freezed
json_serializable
Hive/Drift for local cache
Firebase Messaging
Flutter Secure Storage
```

### 8.2 Backend

```text
NestJS
TypeScript
Prisma ORM
PostgreSQL
PostGIS
Redis
BullMQ
WebSockets / Socket.IO
JWT + refresh tokens
OAuth integrations
```

### 8.3 Storage

```text
S3-compatible object storage
Signed URLs
Image/video thumbnail workers
Optional CDN later
```

### 8.4 AI

```text
LLM provider with structured outputs
NestJS AI orchestration module
Optional Python FastAPI worker for advanced optimization later
```

### 8.5 Web/admin

```text
Next.js
React
Tailwind CSS
shadcn/ui
Admin dashboard only, not main consumer app initially
```

### 8.6 Deployment

MVP options:

- Railway.
- Render.
- Fly.io.
- Supabase PostgreSQL + separate NestJS host.
- AWS Lightsail/ECS later.

Production mature option:

- AWS ECS/Fargate or Kubernetes.
- RDS PostgreSQL.
- ElastiCache Redis.
- S3.
- CloudFront.
- CloudWatch.

---

## 9. Repository structure

Use a monorepo:

```text
ordo/
  apps/
    mobile/                 # Flutter app
    api/                    # NestJS backend
    admin-web/              # Next.js admin dashboard / landing later
  packages/
    contracts/              # Shared API schemas, OpenAPI, DTOs
    design-tokens/          # Shared colors, spacing, icons docs
    docs/                   # Product docs, ADRs, API specs
  infra/
    docker/
    terraform/              # later
    nginx/                  # later
  .github/
    workflows/
  README.md
  CLAUDE.md                 # Coding-agent instructions
```

---

## 10. Backend architecture

### 10.1 Start as modular monolith

Do not start with microservices. Use a modular monolith first.

Modules:

```text
AuthModule
UsersModule
ProfilesModule
GroupsModule
MembershipsModule
PermissionsModule
TimelineModule
AvailabilityModule
CalendarModule
TasksModule
TodosModule
ChatModule
InboxModule
MediaModule
LocationModule
NotificationsModule
RemindersModule
AiModule
IntegrationsModule
AuditModule
SearchModule
```

### 10.2 Layering

Each module should use:

```text
controller -> service -> repository/prisma -> database
```

WebSocket gateways should call services, not database directly.

### 10.3 API style

Use REST for MVP.

Use WebSockets for:

- Chat.
- Typing.
- Timeline updates.
- Task updates.
- Presence.
- Location updates.

GraphQL is not necessary for MVP.

### 10.4 Background jobs

Use BullMQ for:

- Reminders.
- Notification delivery.
- Calendar sync.
- File processing.
- AI summaries.
- Recurring event expansion.
- Cleanup jobs.

### 10.5 Event-driven internal design

Emit internal domain events:

```text
TimelineBlockCreated
TimelineBlockSynced
TaskAssigned
TaskCompleted
MessageCreated
FileUploaded
ReminderDue
LocationSharingEnabled
CalendarSyncCompleted
```

This keeps modules clean.

---

## 11. Database design

### 11.1 Main tables

```text
users
profiles
user_sessions
user_devices
verification_codes

spaces
self_spaces
groups
group_templates
group_members
group_invites
group_permissions

calendar_integrations
external_calendar_accounts
external_busy_blocks

timeline_blocks
timeline_block_syncs
timeline_templates
timeline_categories
timeline_recurrence_rules

group_events
event_attendees
availability_preferences
availability_snapshots

tasks
task_assignees
task_comments
task_attachments
task_activity_logs

todos
todo_items

chat_threads
messages
message_reactions
message_reads
message_attachments

private_threads
private_thread_members

media_files
media_folders

location_shares
location_points

reminders
notifications
notification_preferences

ai_actions
ai_suggestions
ai_conversations

audit_logs
```

### 11.2 Critical schema concepts

#### Users

```sql
users (
  id uuid primary key,
  email text unique,
  phone text unique,
  password_hash text,
  email_verified boolean,
  phone_verified boolean,
  created_at timestamptz,
  updated_at timestamptz,
  deleted_at timestamptz
)
```

#### Groups

```sql
groups (
  id uuid primary key,
  name text not null,
  type text not null,
  avatar_url text,
  created_by uuid references users(id),
  settings jsonb not null default '{}',
  created_at timestamptz,
  updated_at timestamptz
)
```

#### Group members

```sql
group_members (
  id uuid primary key,
  group_id uuid references groups(id),
  user_id uuid references users(id),
  role text not null,
  status text not null,
  permissions jsonb not null default '{}',
  joined_at timestamptz
)
```

#### Timeline blocks

```sql
timeline_blocks (
  id uuid primary key,
  owner_user_id uuid references users(id),
  group_id uuid references groups(id),
  title text not null,
  description text,
  start_time timestamptz not null,
  end_time timestamptz not null,
  timezone text not null,
  visibility text not null,
  category_id uuid,
  recurrence_rule text,
  source text not null,
  created_at timestamptz,
  updated_at timestamptz,
  deleted_at timestamptz
)
```

#### Timeline block syncs

```sql
timeline_block_syncs (
  id uuid primary key,
  timeline_block_id uuid references timeline_blocks(id),
  group_id uuid references groups(id),
  visibility text not null,
  synced_by uuid references users(id),
  created_at timestamptz
)
```

#### Tasks

```sql
tasks (
  id uuid primary key,
  group_id uuid references groups(id),
  created_by uuid references users(id),
  title text not null,
  description text,
  status text not null,
  priority text,
  due_at timestamptz,
  reminder_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz
)
```

#### Messages

```sql
messages (
  id uuid primary key,
  thread_id uuid not null,
  sender_id uuid references users(id),
  body text,
  message_type text not null,
  metadata jsonb not null default '{}',
  created_at timestamptz,
  edited_at timestamptz,
  deleted_at timestamptz
)
```

#### Location points

Use PostGIS geometry/geography:

```sql
location_points (
  id uuid primary key,
  user_id uuid references users(id),
  group_id uuid references groups(id),
  position geography(Point, 4326),
  accuracy_meters integer,
  created_at timestamptz
)
```

### 11.3 Indexes

Recommended indexes:

```sql
create index idx_timeline_user_time on timeline_blocks(owner_user_id, start_time, end_time);
create index idx_timeline_group_time on timeline_blocks(group_id, start_time, end_time);
create index idx_tasks_group_status on tasks(group_id, status);
create index idx_tasks_due_at on tasks(due_at);
create index idx_messages_thread_created on messages(thread_id, created_at);
create index idx_location_points_position on location_points using gist(position);
create index idx_group_settings_gin on groups using gin(settings);
```

---

## 12. Authorization and permissions

### 12.1 Role model

Default roles:

```text
OWNER
ADMIN
MODERATOR
MEMBER
GUEST
```

### 12.2 Permission model

Permissions:

```text
GROUP_UPDATE
GROUP_DELETE
MEMBER_INVITE
MEMBER_REMOVE
MEMBER_ROLE_UPDATE
TIMELINE_CREATE
TIMELINE_UPDATE_OWN
TIMELINE_UPDATE_ANY
EVENT_CREATE
EVENT_UPDATE_OWN
EVENT_UPDATE_ANY
TASK_CREATE
TASK_ASSIGN
TASK_UPDATE_OWN
TASK_UPDATE_ANY
TODO_CREATE
CHAT_SEND
CHAT_DELETE_OWN
CHAT_DELETE_ANY
FILE_UPLOAD
FILE_DELETE_OWN
FILE_DELETE_ANY
LOCATION_VIEW
SETTINGS_UPDATE
```

### 12.3 Use RBAC + ABAC

RBAC answers:

> What is this user’s role?

ABAC answers:

> Is this user allowed to act on this specific object?

Example:

- A member can edit their own task comment.
- An admin can edit any group task.
- No one can view a private timeline block unless explicitly allowed.

### 12.4 Object-level authorization

Every API endpoint using an ID must check that the user has access to that exact object.

Bad:

```text
GET /tasks/:id -> return task if logged in
```

Good:

```text
GET /tasks/:id -> check task belongs to a group where user is member and permission allows read
```

This is critical because broken object-level authorization is one of the major API security risks highlighted by OWASP.

---

## 13. Authentication implementation

### 13.1 Token strategy

Use:

- Access token: 10–15 minutes.
- Refresh token: 30–90 days.
- Refresh-token rotation.
- Store hashed refresh tokens in DB.
- Store refresh token in secure storage on mobile.

### 13.2 Phone OTP

Flow:

1. User enters phone.
2. Backend creates verification code.
3. Send SMS through provider.
4. User submits code.
5. Backend verifies.
6. Create session.

Security:

- Expire OTP after 5–10 minutes.
- Limit resends.
- Limit attempts.
- Store hashed OTP.

### 13.3 Email/password

Security:

- Hash password.
- Email verification.
- Reset password tokens.
- Rate-limit login attempts.
- Device/session screen.

### 13.4 OAuth

For Google Calendar and Google login:

- Use OAuth Authorization Code Flow with PKCE for mobile.
- Store provider tokens encrypted.
- Request only necessary scopes.
- Allow disconnect.

---

## 14. Timeline and recurrence implementation

### 14.1 Core rule

Store the original block and recurrence rule. Generate occurrences for display windows.

Example:

```text
Block: Gym
Start: Monday 7 PM
End: Monday 8 PM
Recurrence: every Monday and Wednesday
```

Generate occurrences only for the visible range:

- Day view: one day.
- Week view: seven days.
- Month view: month range plus padding days.

### 14.2 Timeline templates

Users and groups can create templates:

```text
My study week
Family weekend routine
Gym training month
University semester plan
```

Template contains reusable blocks.

### 14.3 Conflict detection

Conflict happens when two blocks overlap and at least one is not marked as flexible.

Conflict states:

```text
NO_CONFLICT
SOFT_CONFLICT
HARD_CONFLICT
```

Example:

- Soft conflict: “Study” overlaps with “Flexible work.”
- Hard conflict: “Exam” overlaps with “Group meeting.”

### 14.4 Timeline block flexibility

Add field:

```text
fixed | flexible | tentative
```

This improves scheduling.

---

## 15. Empty-slot finder algorithm

### 15.1 Inputs

```json
{
  "groupId": "uuid",
  "dateRangeStart": "2026-06-27T00:00:00+03:00",
  "dateRangeEnd": "2026-06-30T23:59:59+03:00",
  "durationMinutes": 120,
  "requiredMemberIds": [],
  "optionalMemberIds": [],
  "minimumAvailableCount": 6,
  "preferredTimeWindows": ["evening"]
}
```

### 15.2 Steps

1. Load group members.
2. Load each member’s busy blocks for the date range.
3. Load external Google Calendar busy blocks, if connected and allowed.
4. Expand recurring blocks into occurrences.
5. Normalize all intervals to UTC internally.
6. Convert to the group display timezone.
7. Build candidate slots using a 15-minute grid.
8. Remove slots that overlap required members’ busy blocks.
9. Score remaining slots.
10. Return ranked results.

### 15.3 Scoring

Score factors:

```text
+ available member count
+ preferred time of day
+ fewer conflicts
+ not too early/late
+ matches group habits
+ enough travel buffer, future feature
```

### 15.4 Output

```json
{
  "slots": [
    {
      "start": "2026-06-27T19:00:00+03:00",
      "end": "2026-06-27T21:00:00+03:00",
      "availableCount": 8,
      "totalCount": 9,
      "score": 0.92,
      "unavailableMemberIds": ["uuid"]
    }
  ]
}
```

### 15.5 Privacy

When explaining why someone is unavailable, show:

```text
Sara is busy.
```

Do not show:

```text
Sara is at doctor appointment.
```

Unless Sara allowed full details.

---

## 16. Google Calendar integration

### 16.1 MVP capabilities

- Connect Google Calendar.
- Read free/busy blocks.
- Import busy-only blocks into Ordo availability.
- Export Ordo events to Google Calendar.
- Disconnect integration.

### 16.2 Privacy

Default:

- Import only busy/free status.
- Do not import titles/descriptions by default.
- Let user choose calendars.
- Let user choose groups that can use busy data.

### 16.3 Sync strategy

Background job:

```text
calendar-sync-user-{userId}
```

Run:

- On connect.
- Periodically.
- On manual refresh.
- Before empty-slot calculation, if cache is stale.

---

## 17. Notification and reminder system

### 17.1 Reminder lifecycle

```text
CREATED -> SCHEDULED -> SENT -> ACKNOWLEDGED
                     -> FAILED -> RETRYING
                     -> CANCELLED
```

### 17.2 Reminder scheduler

Use BullMQ delayed jobs.

When a task/event/timeline block changes:

1. Cancel old reminder job.
2. Create new reminder job.
3. Save reminder ID.
4. Send push notification when due.

### 17.3 Notification preferences

Per user:

- Push on/off.
- Email on/off.
- Quiet hours.
- Group-specific notification level.
- Mention-only mode.
- Reminder lead time.

Per group:

```text
All notifications
Important only
Mentions only
Muted
```

---

## 18. Chat and realtime implementation

### 18.1 WebSocket channels

```text
group:{groupId}:chat
group:{groupId}:timeline
group:{groupId}:tasks
group:{groupId}:presence
private:{threadId}
user:{userId}:notifications
```

### 18.2 Events

```text
message.created
message.updated
message.deleted
typing.started
typing.stopped
task.assigned
task.updated
timeline.block.created
timeline.block.updated
location.updated
notification.created
```

### 18.3 Offline handling

Mobile app should:

- Cache recent groups.
- Cache timeline.
- Cache tasks.
- Queue offline changes where safe.
- Sync when online.

Do not allow risky offline actions without conflict resolution.

---

## 19. AI system design

### 19.1 AI architecture

```text
Flutter UI
  -> NestJS AI Module
    -> Permission checker
    -> Context builder
    -> LLM structured output
    -> Validation
    -> User confirmation
    -> Action executor
```

### 19.2 AI must not bypass permissions

AI can only act through the same services as normal users.

Bad:

```text
AI writes directly to database.
```

Good:

```text
AI proposes JSON -> backend validates -> user confirms -> service executes with permission checks.
```

### 19.3 AI functions

#### Natural language event creation

Input:

```text
Create a family dinner next Friday at 8 PM and remind everyone 1 hour before.
```

AI output:

```json
{
  "action": "CREATE_EVENT",
  "groupName": "Family",
  "title": "Family dinner",
  "startTime": "2026-07-03T20:00:00+03:00",
  "reminderMinutesBefore": 60
}
```

#### Task extraction from chat

Message:

```text
Omar, please bring the projector tomorrow.
```

Suggestion:

```json
{
  "action": "CREATE_TASK",
  "assignee": "Omar",
  "title": "Bring the projector",
  "dueDate": "tomorrow"
}
```

#### Smart summary

Output:

```text
Today in University group:
- Assignment deadline moved to Thursday.
- Sara uploaded lecture notes.
- Omar was assigned the presentation file.
- Best available study slot is Wednesday 6–8 PM.
```

### 19.4 AI safety UX

All destructive or group-visible actions require confirmation:

- Create group event.
- Assign task to others.
- Change timeline visibility.
- Send message.
- Delete/update data.
- Enable location.

AI can auto-generate drafts, not auto-commit sensitive changes.

---

## 20. API endpoint outline

### Auth

```text
POST /auth/register
POST /auth/login
POST /auth/refresh
POST /auth/logout
POST /auth/request-otp
POST /auth/verify-otp
POST /auth/forgot-password
POST /auth/reset-password
GET  /auth/sessions
DELETE /auth/sessions/:id
```

### Users/profile

```text
GET  /me
PATCH /me/profile
PATCH /me/preferences
DELETE /me
```

### Groups

```text
POST /groups
GET  /groups
GET  /groups/:groupId
PATCH /groups/:groupId
DELETE /groups/:groupId
POST /groups/:groupId/invites
GET  /groups/:groupId/members
PATCH /groups/:groupId/members/:memberId
DELETE /groups/:groupId/members/:memberId
```

### Timeline

```text
POST /timeline/blocks
GET  /timeline/blocks
GET  /timeline/blocks/:blockId
PATCH /timeline/blocks/:blockId
DELETE /timeline/blocks/:blockId
POST /timeline/blocks/:blockId/sync
POST /timeline/find-free-slots
GET  /groups/:groupId/timeline
GET  /me/timeline
```

### Calendar

```text
POST /calendar/google/connect
DELETE /calendar/google/disconnect
POST /calendar/sync
GET  /calendar/events
POST /calendar/events
PATCH /calendar/events/:eventId
DELETE /calendar/events/:eventId
POST /calendar/freebusy
```

### Tasks/to-dos

```text
POST /tasks
GET  /tasks
GET  /tasks/:taskId
PATCH /tasks/:taskId
DELETE /tasks/:taskId
POST /tasks/:taskId/comments
POST /tasks/:taskId/attachments

POST /todos
GET  /todos
PATCH /todos/:todoId
DELETE /todos/:todoId
```

### Chat

```text
GET  /groups/:groupId/messages
POST /groups/:groupId/messages
PATCH /messages/:messageId
DELETE /messages/:messageId
POST /messages/:messageId/reactions
```

### Media

```text
POST /media/presign-upload
POST /media/complete-upload
GET  /media/:fileId
DELETE /media/:fileId
```

### AI

```text
POST /ai/parse-command
POST /ai/summarize-group
POST /ai/suggest-slots
POST /ai/extract-tasks
POST /ai/plan-day
POST /ai/apply-suggestion
```

---

## 21. Flutter app architecture

### 21.1 Folder structure

```text
lib/
  main.dart
  app/
    app.dart
    router/
    theme/
    localization/
  core/
    api/
    auth/
    cache/
    errors/
    permissions/
    realtime/
    notifications/
    storage/
    utils/
  features/
    onboarding/
    auth/
    today/
    groups/
    timeline/
    availability/
    calendar/
    tasks/
    todos/
    chat/
    inbox/
    media/
    location/
    profile/
    settings/
    ai/
  shared/
    widgets/
    models/
    extensions/
    animations/
```

### 21.2 State management

Use Riverpod providers:

```text
authProvider
groupsProvider
timelineProvider
tasksProvider
chatProvider
notificationsProvider
themeProvider
```

### 21.3 Routing

Use go_router:

```text
/
/login
/register
/onboarding
/today
/groups
/groups/:groupId
/groups/:groupId/timeline
/groups/:groupId/tasks
/groups/:groupId/chat
/timeline
/inbox
/profile
/settings
```

### 21.4 Local storage

Use:

- Secure storage for tokens.
- Hive or Drift for cached timeline/tasks/messages.
- Shared preferences for non-sensitive UI preferences.

### 21.5 Error handling

Every feature should have:

- Loading state.
- Empty state.
- Error state.
- Retry button.
- Offline message.

---

## 22. Admin dashboard

Build later with Next.js.

Admin dashboard features:

- User management.
- Reported content.
- App analytics.
- System health.
- Feature flags.
- Group moderation.
- Notification campaigns.
- AI logs review.

Do not build full admin dashboard in the first mobile MVP unless needed.

---

## 23. Security and privacy checklist

### 23.1 API security

- Object-level authorization for every resource.
- Rate limiting.
- Input validation.
- DTO validation.
- Audit logs.
- Secure file upload validation.
- Avoid exposing sequential IDs.
- Use UUIDs.
- Encrypt sensitive tokens.
- Sanitize user-generated content.
- Protect WebSocket authentication.

### 23.2 Privacy

- Private timeline by default.
- Busy-only external calendar by default.
- Location opt-in only.
- Location expiry.
- Data export.
- Account deletion.
- Group-level privacy controls.
- Clear visibility indicators.

### 23.3 Push notification privacy

Do not send sensitive message content in push payloads by default.

Bad:

```text
Sara: I am at the doctor.
```

Better:

```text
New message in Family group.
```

Give users a setting for detailed previews.

---

## 24. MVP vs full version

### 24.1 MVP — build first

Must include:

- Auth.
- Profile.
- Self timeline: day/week/month.
- Group creation.
- Group timeline: day/week/month.
- Timeline sync with privacy.
- Basic availability finder.
- Tasks.
- To-dos.
- Reminders.
- Group chat.
- Basic files.
- Push notifications.
- Basic Google Calendar free/busy.
- Light/dark themes.

### 24.2 Version 1.5

Add:

- AI natural language creation.
- AI group summary.
- Task extraction from chat.
- Improved recurring events.
- Better file previews.
- Search.
- Polls.

### 24.3 Version 2

Add:

- Location sharing.
- Advanced admin customization.
- Group templates marketplace.
- Web app.
- Advanced analytics.
- AI schedule negotiation.
- Voice commands.
- Widgets.

### 24.4 Version 3

Add:

- End-to-end encrypted private inbox.
- Smart automations.
- Family safety features.
- Enterprise/workspace mode.
- Public communities, only if strategically desired.

---

## 25. Implementation roadmap

### Phase 0 — Product/design foundation

Deliverables:

- Final feature list.
- Information architecture.
- Figma design system.
- User flows.
- Database ERD.
- API contract draft.
- Monorepo setup.

### Phase 1 — Backend foundation

Deliverables:

- NestJS project.
- Prisma setup.
- PostgreSQL schema.
- Auth module.
- User/profile module.
- Groups module.
- Permissions module.
- Docker Compose.

### Phase 2 — Flutter foundation

Deliverables:

- Flutter project.
- Theme system.
- Routing.
- Auth screens.
- Secure token storage.
- Core design components.
- Main shell navigation.

### Phase 3 — Groups and timeline

Deliverables:

- Create group.
- Group home.
- Self timeline day/week/month.
- Group timeline day/week/month.
- Add/edit/delete block.
- Visibility controls.
- Timeline sync.

### Phase 4 — Tasks, to-dos, reminders

Deliverables:

- Task module backend.
- To-do module backend.
- Task UI.
- To-do UI.
- Reminder scheduler.
- Push notification integration.

### Phase 5 — Availability finder

Deliverables:

- Busy interval model.
- Free-slot algorithm.
- Availability finder UI.
- Create event from slot.
- Conflict detection.

### Phase 6 — Chat and files

Deliverables:

- WebSocket setup.
- Group chat.
- Private inbox MVP.
- File upload.
- Message attachments.
- Realtime updates.

### Phase 7 — Google Calendar

Deliverables:

- OAuth connect.
- Free/busy import.
- Export Ordo events.
- Sync jobs.
- Privacy settings.

### Phase 8 — AI assistant

Deliverables:

- AI command parser.
- Structured output schemas.
- AI review cards.
- Task extraction.
- Group summary.
- Schedule suggestion.

### Phase 9 — Polish and production readiness

Deliverables:

- Error states.
- Empty states.
- Offline cache.
- Performance optimization.
- Testing.
- Security review.
- App Store/Play Store preparation.

---

## 26. Testing plan

### 26.1 Backend tests

- Unit tests for services.
- Integration tests for API endpoints.
- Permission tests.
- Timeline overlap tests.
- Free-slot algorithm tests.
- Reminder scheduler tests.
- WebSocket tests.

### 26.2 Flutter tests

- Widget tests for components.
- Screen tests for critical flows.
- Golden tests for design consistency.
- Integration tests for auth, group creation, timeline creation.

### 26.3 Security tests

- IDOR/BOLA tests.
- Rate-limit tests.
- Upload validation tests.
- Token refresh tests.
- WebSocket auth tests.

### 26.4 AI tests

- Schema validation tests.
- Hallucinated member test.
- Wrong group test.
- Permission bypass test.
- Date/time ambiguity test.
- Confirmation-required action test.

---

## 27. Performance targets

### 27.1 Mobile

- App cold start under 2.5 seconds on modern devices.
- Timeline screen loads cached data immediately.
- API refresh in background.
- 60fps animations where possible.
- Avoid heavy rebuilds in timeline views.

### 27.2 Backend

- Common API responses under 300ms excluding external services.
- Free-slot finder under 1 second for normal groups.
- Chat message delivery near realtime.
- Background sync must not block user interactions.

### 27.3 Database

- Index all timeline range queries.
- Index group membership checks.
- Archive old messages/files metadata if needed later.
- Use pagination everywhere.

---

## 28. Monetization ideas, later

Do not focus on monetization before product-market fit.

Possible plans:

### Free

- Limited groups.
- Limited storage.
- Basic timelines.
- Basic tasks.

### Plus

- More groups.
- More storage.
- AI summaries.
- Advanced recurring plans.
- Calendar integrations.

### Family plan

- Family location.
- Shared routines.
- More reminders.
- Emergency alerts, future.

### Teams/University plan

- Admin dashboard.
- Advanced permissions.
- Bulk members.
- Analytics.

---

## 29. Differentiating features to make Ordo special

### 29.1 Privacy-controlled timeline sync

This is the strongest feature.

### 29.2 Daily/weekly/monthly planning everywhere

Self and every group have day/week/month timelines.

### 29.3 Empty-slot finder

This turns passive calendars into active coordination.

### 29.4 AI review cards

AI helps without taking control.

### 29.5 Group templates

Family, university, gym, sports, friends, work — each starts with the right modules.

### 29.6 Time-aware chat

Messages can become tasks, events, reminders, or files.

---

## 30. Claude Opus 4.8 / coding-agent implementation instructions

Create a `CLAUDE.md` file in the repo with this content:

```markdown
# Ordo Coding Agent Instructions

You are helping build Ordo, a time-first group coordination app.

## Product identity
Ordo is not a chat clone. It is a shared life coordination system centered on daily, weekly, and monthly timelines, privacy-controlled availability, group tasks, reminders, chat, files, and AI scheduling support.

## Technical stack
- Mobile: Flutter + Riverpod + go_router + Dio.
- Backend: NestJS + Prisma + PostgreSQL + Redis + BullMQ.
- Realtime: NestJS WebSocket gateways.
- Storage: S3-compatible object storage.
- Notifications: FCM/APNs.
- Calendar: Google Calendar API.
- AI: structured JSON outputs, validated before execution.

## Non-negotiable architecture rules
1. Start as a modular monolith, not microservices.
2. Never bypass authorization checks.
3. Every resource endpoint must enforce object-level authorization.
4. AI must never write directly to the database.
5. AI suggestions must be validated and confirmed by the user before sensitive actions.
6. Timeline privacy is core: PRIVATE, BUSY_ONLY, TITLE_ONLY, FULL.
7. Location sharing is opt-in and group-specific.
8. Push notification payloads must not expose sensitive content by default.
9. Use UTC internally and display in the user's timezone.
10. Add tests for permissions, timeline overlap, free-slot finder, and AI schema validation.

## Implementation sequence
1. Monorepo setup.
2. Backend foundation.
3. Auth and profile.
4. Groups and membership.
5. Permissions.
6. Flutter app foundation and design system.
7. Self timeline.
8. Group timeline.
9. Timeline sync and privacy.
10. Tasks/to-dos/reminders.
11. Availability finder.
12. Chat/files.
13. Google Calendar.
14. AI assistant.
15. Polish, tests, deployment.

## UX rules
- Most common actions should take no more than two taps.
- Every screen needs loading, empty, error, and offline states where relevant.
- Use clean cards, soft borders, strong typography, and smooth transitions.
- Keep chat secondary to timeline and coordination.

## Code quality
- Use strict TypeScript on backend.
- Use DTO validation in NestJS.
- Use Prisma migrations.
- Use Riverpod for Flutter state.
- Keep widgets small and reusable.
- Write tests before complex algorithm changes.
- Update docs when changing architecture.
```

---

## 31. Immediate next implementation tasks

### Task 1 — Create monorepo

```bash
mkdir ordo
cd ordo
mkdir -p apps/mobile apps/api apps/admin-web packages/contracts packages/design-tokens docs infra/docker
```

### Task 2 — Create backend

```bash
cd apps
nest new api
```

Install backend dependencies:

```bash
npm install @nestjs/config @nestjs/jwt @nestjs/passport passport passport-jwt bcrypt class-validator class-transformer
npm install prisma @prisma/client
npm install redis bullmq
npm install socket.io @nestjs/websockets @nestjs/platform-socket.io
```

### Task 3 — Create Flutter app

```bash
cd apps
flutter create mobile
```

Add Flutter dependencies:

```yaml
dependencies:
  flutter_riverpod:
  go_router:
  dio:
  freezed_annotation:
  json_annotation:
  flutter_secure_storage:
  shared_preferences:
  firebase_messaging:
  intl:
```

### Task 4 — Create Docker Compose

Services:

- PostgreSQL.
- Redis.
- NestJS API.
- Optional MinIO for local S3-compatible storage.

### Task 5 — Design first screens

Start with:

1. Welcome.
2. Login/register.
3. Today.
4. Groups.
5. Self timeline.
6. Group home.
7. Add timeline block sheet.

---

## 32. Final strategic advice

The best version of Ordo is not the version with the most features. It is the version where users instantly understand:

> “This app helps me know what I am doing, what my groups are doing, when everyone is free, and what needs to be done.”

Build the first version around four pillars:

1. **Timeline** — daily, weekly, monthly.
2. **Groups** — shared spaces, not just chats.
3. **Availability** — find empty slots quickly.
4. **Privacy** — share busy time without exposing personal details.

Everything else should support these pillars.

If Ordo gets these four pillars right, it can become a genuinely strong application rather than another overloaded productivity app.
