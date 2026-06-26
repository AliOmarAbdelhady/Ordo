import 'package:flutter/material.dart';

DateTime _dt(dynamic v) => v is String ? DateTime.parse(v) : (v as DateTime);

class User {
  final String id;
  final String email;
  final String name;
  final String username;
  final String? avatarUrl;
  final String timezone;
  final String theme;
  final String accentColor;
  final String? bio;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.username,
    this.avatarUrl,
    required this.timezone,
    required this.theme,
    required this.accentColor,
    this.bio,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'],
        email: j['email'],
        name: j['name'],
        username: j['username'],
        avatarUrl: j['avatarUrl'],
        timezone: j['timezone'] ?? 'UTC',
        theme: j['theme'] ?? 'system',
        accentColor: j['accentColor'] ?? 'blue',
        bio: j['bio'],
        createdAt: _dt(j['createdAt']),
      );
}

class GroupModules {
  final bool timeline, calendar, tasks, todo, chat, files, location, members, announcements, polls, media, availability;
  const GroupModules({
    this.timeline = false,
    this.calendar = false,
    this.tasks = false,
    this.todo = false,
    this.chat = false,
    this.files = false,
    this.location = false,
    this.members = true,
    this.announcements = false,
    this.polls = false,
    this.media = false,
    this.availability = false,
  });

  factory GroupModules.fromJson(Map<String, dynamic> j) => GroupModules(
        timeline: j['timeline'] ?? false,
        calendar: j['calendar'] ?? false,
        tasks: j['tasks'] ?? false,
        todo: j['todo'] ?? false,
        chat: j['chat'] ?? false,
        files: j['files'] ?? false,
        location: j['location'] ?? false,
        members: j['members'] ?? true,
        announcements: j['announcements'] ?? false,
        polls: j['polls'] ?? false,
        media: j['media'] ?? false,
        availability: j['availability'] ?? false,
      );
}

class Group {
  final String id;
  final String name;
  final String type;
  final String? description;
  final String? avatarUrl;
  final String accentColor;
  final GroupModules modules;
  final String role;
  final int memberCount;
  final int pendingTaskCount;
  final int unreadCount;
  final GroupNextEvent? nextEvent;
  final bool pinned;

  Group({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    this.avatarUrl,
    required this.accentColor,
    required this.modules,
    required this.role,
    required this.memberCount,
    required this.pendingTaskCount,
    required this.unreadCount,
    this.nextEvent,
    required this.pinned,
  });

  factory Group.fromJson(Map<String, dynamic> j) => Group(
        id: j['id'],
        name: j['name'],
        type: j['type'] ?? 'CUSTOM',
        description: j['description'],
        avatarUrl: j['avatarUrl'],
        accentColor: j['accentColor'] ?? 'blue',
        modules: GroupModules.fromJson((j['modules'] as Map<String, dynamic>?) ?? {}),
        role: j['role'] ?? 'MEMBER',
        memberCount: j['memberCount'] ?? 0,
        pendingTaskCount: j['pendingTaskCount'] ?? 0,
        unreadCount: j['unreadCount'] ?? 0,
        nextEvent: j['nextEvent'] != null ? GroupNextEvent.fromJson(j['nextEvent']) : null,
        pinned: j['pinned'] ?? false,
      );
}

class GroupNextEvent {
  final String id;
  final String title;
  final DateTime startTime;
  GroupNextEvent({required this.id, required this.title, required this.startTime});
  factory GroupNextEvent.fromJson(Map<String, dynamic> j) =>
      GroupNextEvent(id: j['id'], title: j['title'], startTime: _dt(j['startTime']));
}

class GroupMember {
  final String id;
  final String userId;
  final String role;
  final DateTime joinedAt;
  final String name;
  final String? avatarUrl;
  GroupMember({required this.id, required this.userId, required this.role, required this.joinedAt, required this.name, this.avatarUrl});
  factory GroupMember.fromJson(Map<String, dynamic> j) => GroupMember(
        id: j['id'],
        userId: j['userId'],
        role: j['role'],
        joinedAt: _dt(j['joinedAt']),
        name: j['user']?['name'] ?? 'Unknown',
        avatarUrl: j['user']?['avatarUrl'],
      );
}

class GroupDetail extends Group {
  final List<GroupMember> members;
  GroupDetail({
    required super.id,
    required super.name,
    required super.type,
    super.description,
    super.avatarUrl,
    required super.accentColor,
    required super.modules,
    required super.role,
    required super.memberCount,
    required super.pendingTaskCount,
    required super.unreadCount,
    super.nextEvent,
    required super.pinned,
    required this.members,
  });

  factory GroupDetail.fromJson(Map<String, dynamic> j) => GroupDetail(
        id: j['id'],
        name: j['name'],
        type: j['type'] ?? 'CUSTOM',
        description: j['description'],
        avatarUrl: j['avatarUrl'],
        accentColor: j['accentColor'] ?? 'blue',
        modules: GroupModules.fromJson((j['modules'] as Map<String, dynamic>?) ?? {}),
        role: j['role'] ?? 'MEMBER',
        memberCount: j['memberCount'] ?? 0,
        pendingTaskCount: j['pendingTaskCount'] ?? 0,
        unreadCount: j['unreadCount'] ?? 0,
        nextEvent: j['nextEvent'] != null ? GroupNextEvent.fromJson(j['nextEvent']) : null,
        pinned: j['pinned'] ?? false,
        members: ((j['members'] as List?) ?? []).map((e) => GroupMember.fromJson(e)).toList(),
      );
}

class TemplateInfo {
  final String type;
  final String name;
  final String emoji;
  final String description;
  final String accentColor;
  final GroupModules modules;
  TemplateInfo({required this.type, required this.name, required this.emoji, required this.description, required this.accentColor, required this.modules});
  factory TemplateInfo.fromJson(Map<String, dynamic> j) => TemplateInfo(
        type: j['type'],
        name: j['name'],
        emoji: j['emoji'] ?? '✨',
        description: j['description'] ?? '',
        accentColor: j['accentColor'] ?? 'blue',
        modules: GroupModules.fromJson((j['modules'] as Map<String, dynamic>?) ?? {}),
      );
}

/// A privacy-aware timeline block occurrence (server already redacted).
class TimelineItem {
  final String id;
  final String instanceId;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final Color color;
  final String? location;
  final String visibility;
  final String? ownerId;
  final String? groupId;
  final String createdById;
  final bool isEvent;
  final bool allDay;
  final String source;
  final bool isOwn;
  final bool isBusy;
  final bool redacted;
  final int? reminderMinutesBefore;

  TimelineItem({
    required this.id,
    required this.instanceId,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    required this.color,
    this.location,
    required this.visibility,
    this.ownerId,
    this.groupId,
    required this.createdById,
    required this.isEvent,
    required this.allDay,
    required this.source,
    required this.isOwn,
    required this.isBusy,
    required this.redacted,
    this.reminderMinutesBefore,
  });

  factory TimelineItem.fromJson(Map<String, dynamic> j) {
    final color = _color(j['color'] ?? '#2563EB');
    return TimelineItem(
      id: j['id'],
      instanceId: j['instanceId'] ?? j['id'],
      title: j['title'] ?? '',
      description: j['description'],
      startTime: _dt(j['startTime']),
      endTime: _dt(j['endTime']),
      color: color,
      location: j['location'],
      visibility: j['visibility'] ?? 'PRIVATE',
      ownerId: j['ownerId'],
      groupId: j['groupId'],
      createdById: j['createdById'],
      isEvent: j['isEvent'] ?? false,
      allDay: j['allDay'] ?? false,
      source: j['source'] ?? 'SELF',
      isOwn: j['isOwn'] ?? false,
      isBusy: j['isBusy'] ?? false,
      redacted: j['redacted'] ?? false,
      reminderMinutesBefore: j['reminderMinutesBefore'],
    );
  }
}

/// Full-detail block (only returned for blocks the user owns/created).
class BlockDetail {
  final String id;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final String timezone;
  final String visibility;
  final String flexibility;
  final Color color;
  final String? location;
  final String? recurrenceRule;
  final bool isEvent;
  final bool allDay;
  final String source;
  final String? groupId;
  final int? reminderMinutesBefore;

  BlockDetail({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    required this.timezone,
    required this.visibility,
    required this.flexibility,
    required this.color,
    this.location,
    this.recurrenceRule,
    required this.isEvent,
    required this.allDay,
    required this.source,
    this.groupId,
    this.reminderMinutesBefore,
  });

  factory BlockDetail.fromJson(Map<String, dynamic> j) => BlockDetail(
        id: j['id'],
        title: j['title'],
        description: j['description'],
        startTime: _dt(j['startTime']),
        endTime: _dt(j['endTime']),
        timezone: j['timezone'] ?? 'UTC',
        visibility: j['visibility'] ?? 'PRIVATE',
        flexibility: j['flexibility'] ?? 'FIXED',
        color: _color(j['color'] ?? '#2563EB'),
        location: j['location'],
        recurrenceRule: j['recurrenceRule'],
        isEvent: j['isEvent'] ?? false,
        allDay: j['allDay'] ?? false,
        source: j['source'] ?? 'SELF',
        groupId: j['groupId'],
        reminderMinutesBefore: j['reminderMinutesBefore'],
      );
}

class SyncEntry {
  final String groupId;
  final String visibility;
  SyncEntry({required this.groupId, required this.visibility});
  Map<String, dynamic> toJson() => {'groupId': groupId, 'visibility': visibility};
}

class SlotResult {
  final DateTime start;
  final DateTime end;
  final int availableCount;
  final int totalCount;
  final double score;
  final String window;
  final List<String> unavailableMemberIds;
  SlotResult({required this.start, required this.end, required this.availableCount, required this.totalCount, required this.score, required this.window, required this.unavailableMemberIds});
  factory SlotResult.fromJson(Map<String, dynamic> j) => SlotResult(
        start: _dt(j['start']),
        end: _dt(j['end']),
        availableCount: j['availableCount'] ?? 0,
        totalCount: j['totalCount'] ?? 0,
        score: (j['score'] ?? 0).toDouble(),
        window: j['window'] ?? '',
        unavailableMemberIds: ((j['unavailableMemberIds'] as List?) ?? []).map((e) => e.toString()).toList(),
      );
}

class StripMember {
  final String id;
  final String name;
  final String? avatarUrl;
  final List<BusyInterval> busy;
  StripMember({required this.id, required this.name, this.avatarUrl, required this.busy});
  factory StripMember.fromJson(Map<String, dynamic> j) => StripMember(
        id: j['id'],
        name: j['name'] ?? '',
        avatarUrl: j['avatarUrl'],
        busy: ((j['busy'] as List?) ?? []).map((e) => BusyInterval.fromJson(e)).toList(),
      );
}

class BusyInterval {
  final DateTime start;
  final DateTime end;
  BusyInterval({required this.start, required this.end});
  factory BusyInterval.fromJson(Map<String, dynamic> j) => BusyInterval(start: _dt(j['start']), end: _dt(j['end']));
}

class Task {
  final String id;
  final String groupId;
  final String title;
  final String? description;
  final String status;
  final String priority;
  final DateTime? dueAt;
  final DateTime createdAt;
  final String createdByName;
  final String? createdByAvatar;
  final List<Assignee> assignees;
  final int commentCount;

  Task({
    required this.id,
    required this.groupId,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    this.dueAt,
    required this.createdAt,
    required this.createdByName,
    this.createdByAvatar,
    required this.assignees,
    required this.commentCount,
  });

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'],
        groupId: j['groupId'],
        title: j['title'],
        description: j['description'],
        status: j['status'] ?? 'TODO',
        priority: j['priority'] ?? 'MEDIUM',
        dueAt: j['dueAt'] != null ? _dt(j['dueAt']) : null,
        createdAt: _dt(j['createdAt']),
        createdByName: j['createdBy']?['name'] ?? 'Unknown',
        createdByAvatar: j['createdBy']?['avatarUrl'],
        assignees: ((j['assignees'] as List?) ?? []).map((e) => Assignee.fromJson(e)).toList(),
        commentCount: j['commentCount'] ?? 0,
      );
}

class Assignee {
  final String id;
  final String name;
  final String? avatarUrl;
  Assignee({required this.id, required this.name, this.avatarUrl});
  factory Assignee.fromJson(Map<String, dynamic> j) => Assignee(id: j['id'], name: j['name'] ?? '', avatarUrl: j['avatarUrl']);
}

class TaskComment {
  final String id;
  final String body;
  final DateTime createdAt;
  final String userName;
  final String? userAvatar;
  TaskComment({required this.id, required this.body, required this.createdAt, required this.userName, this.userAvatar});
  factory TaskComment.fromJson(Map<String, dynamic> j) => TaskComment(
        id: j['id'],
        body: j['body'] ?? '',
        createdAt: _dt(j['createdAt']),
        userName: j['user']?['name'] ?? 'Unknown',
        userAvatar: j['user']?['avatarUrl'],
      );
}

class Todo {
  final String id;
  final String title;
  final String? note;
  final bool done;
  final DateTime? dueAt;
  final int order;
  final List<String> labels;
  final String? groupId;
  Todo({required this.id, required this.title, this.note, required this.done, this.dueAt, required this.order, required this.labels, this.groupId});
  factory Todo.fromJson(Map<String, dynamic> j) => Todo(
        id: j['id'],
        title: j['title'],
        note: j['note'],
        done: j['done'] ?? false,
        dueAt: j['dueAt'] != null ? _dt(j['dueAt']) : null,
        order: j['order'] ?? 0,
        labels: ((j['labels'] as List?) ?? []).map((e) => e.toString()).toList(),
        groupId: j['groupId'],
      );
}

class ChatMessage {
  final String id;
  final String groupId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String? body;
  final String type;
  final String? replyToId;
  final String? replyToBody;
  final String? replyToSender;
  final DateTime createdAt;
  final DateTime? editedAt;
  final bool deleted;
  final List<MessageReaction> reactions;

  ChatMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    this.body,
    required this.type,
    this.replyToId,
    this.replyToBody,
    this.replyToSender,
    required this.createdAt,
    this.editedAt,
    required this.deleted,
    required this.reactions,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'],
        groupId: j['groupId'],
        senderId: j['senderId'],
        senderName: j['sender']?['name'] ?? 'Unknown',
        senderAvatar: j['sender']?['avatarUrl'],
        body: j['body'],
        type: j['type'] ?? 'TEXT',
        replyToId: j['replyToId'],
        replyToBody: j['replyTo']?['body'],
        replyToSender: j['replyTo']?['senderName'],
        createdAt: _dt(j['createdAt']),
        editedAt: j['editedAt'] != null ? _dt(j['editedAt']) : null,
        deleted: j['deleted'] ?? false,
        reactions: ((j['reactions'] as List?) ?? []).map((e) => MessageReaction.fromJson(e)).toList(),
      );

  ChatMessage copyWith({List<MessageReaction>? reactions, String? body, DateTime? editedAt, bool? deleted}) =>
      ChatMessage(
        id: id,
        groupId: groupId,
        senderId: senderId,
        senderName: senderName,
        senderAvatar: senderAvatar,
        body: body ?? this.body,
        type: type,
        replyToId: replyToId,
        replyToBody: replyToBody,
        replyToSender: replyToSender,
        createdAt: createdAt,
        editedAt: editedAt ?? this.editedAt,
        deleted: deleted ?? this.deleted,
        reactions: reactions ?? this.reactions,
      );
}

class MessageReaction {
  final String emoji;
  final int count;
  final List<String> userIds;
  MessageReaction({required this.emoji, required this.count, required this.userIds});
  factory MessageReaction.fromJson(Map<String, dynamic> j) => MessageReaction(
        emoji: j['emoji'],
        count: j['count'] ?? 0,
        userIds: ((j['userIds'] as List?) ?? []).map((e) => e.toString()).toList(),
      );
}

class OrdoNotification {
  final String id;
  final String type;
  final String title;
  final String? body;
  final Map<String, dynamic> data;
  final bool read;
  final DateTime createdAt;
  OrdoNotification({required this.id, required this.type, required this.title, this.body, required this.data, required this.read, required this.createdAt});
  factory OrdoNotification.fromJson(Map<String, dynamic> j) => OrdoNotification(
        id: j['id'],
        type: j['type'] ?? 'SYSTEM',
        title: j['title'] ?? '',
        body: j['body'],
        data: (j['data'] as Map<String, dynamic>?) ?? {},
        read: j['read'] ?? false,
        createdAt: _dt(j['createdAt']),
      );
}

class AvailabilityPrefs {
  final String timezone;
  final String workStart;
  final String workEnd;
  final String sleepStart;
  final String sleepEnd;
  final List<int> weekdays;
  AvailabilityPrefs({required this.timezone, required this.workStart, required this.workEnd, required this.sleepStart, required this.sleepEnd, required this.weekdays});
  factory AvailabilityPrefs.fromJson(Map<String, dynamic> j) => AvailabilityPrefs(
        timezone: j['timezone'] ?? 'UTC',
        workStart: j['workStart'] ?? '09:00',
        workEnd: j['workEnd'] ?? '17:00',
        sleepStart: j['sleepStart'] ?? '23:00',
        sleepEnd: j['sleepEnd'] ?? '07:00',
        weekdays: ((j['weekdays'] as List?) ?? [1, 2, 3, 4, 5]).map((e) => e as int).toList(),
      );
}

Color _color(String hex) {
  var h = hex.replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}
