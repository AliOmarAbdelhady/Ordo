import 'package:intl/intl.dart';

String fmtTime(DateTime dt) => DateFormat('h:mm a').format(dt);
String fmtTime24(DateTime dt) => DateFormat('HH:mm').format(dt);
String fmtDate(DateTime dt) => DateFormat('EEE, MMM d').format(dt);
String fmtDateLong(DateTime dt) => DateFormat('EEEE, MMMM d').format(dt);
String fmtMonthYear(DateTime dt) => DateFormat('MMMM yyyy').format(dt);
String fmtDateTime(DateTime dt) => DateFormat('EEE, MMM d · h:mm a').format(dt);
String fmtDayMonth(DateTime dt) => DateFormat('MMM d').format(dt);

String fmtRange(DateTime start, DateTime end) {
  final s = DateFormat('h:mm a').format(start);
  final e = DateFormat('h:mm a').format(end);
  return '$s – $e';
}

String fmtRelative(DateTime dt) {
  final now = DateTime.now();
  final diff = dt.difference(now);
  final abs = diff.abs();
  if (abs.inMinutes < 1) return 'just now';
  if (abs.inHours < 1) return diff.isNegative ? '${abs.inMinutes}m ago' : 'in ${abs.inMinutes}m';
  if (abs.inDays < 1) return diff.isNegative ? '${abs.inHours}h ago' : 'in ${abs.inHours}h';
  if (diff.isNegative) return abs.inDays == 1 ? 'yesterday' : '${abs.inDays}d ago';
  if (abs.inDays == 1) return 'tomorrow';
  if (abs.inDays < 7) return 'in ${abs.inDays}d';
  return DateFormat('MMM d').format(dt);
}

String dayLabel(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(dt.year, dt.month, dt.day);
  final diff = d.difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  if (diff > 1 && diff < 7) return DateFormat('EEEE').format(dt);
  return DateFormat('EEE, MMM d').format(dt);
}

String fmtDuration(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

String initials(String? name) {
  if (name == null || name.isEmpty) return '?';
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return (parts[0][0] + parts.last[0]).toUpperCase();
}

int colorFromString(String str) {
  final palette = [
    0xFF2563eb, 0xFF16a34a, 0xFFdc2626, 0xFF9333ea, 0xFFea580c,
    0xFF0891b2, 0xFFdb2777, 0xFF65a30d, 0xFF7c3aed, 0xFF0d9488,
  0xFF4f46e5, 0xFFca8a04,
  ];
  var hash = 0;
  for (final c in str.codeUnits) {
    hash = c + ((hash << 5) - hash);
  }
  return palette[hash.abs() % palette.length];
}

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime addDays(DateTime d, int n) {
  final x = DateTime(d.year, d.month, d.day);
  return x.add(Duration(days: n));
}
DateTime startOfWeek(DateTime d, {int weekStart = DateTime.monday}) {
  final today = startOfDay(d);
  return today.subtract(Duration(days: (today.weekday - weekStart) % 7));
}
bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
