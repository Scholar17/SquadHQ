const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatMatchDate(DateTime kickoffAt) {
  final local = kickoffAt.toLocal();
  return '${weekdayNames[local.weekday - 1]}, ${local.day} ${monthNames[local.month - 1]}';
}

String formatMatchTime(DateTime kickoffAt) {
  final local = kickoffAt.toLocal();
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '$hour12:$minute $period';
}

String formatMatchDateTime(DateTime kickoffAt) =>
    '${formatMatchDate(kickoffAt)} · ${formatMatchTime(kickoffAt)}';

/// Play time, e.g. "1 hr", "1.5 hr", "45 min".
String formatPlayTime(int minutes) {
  if (minutes < 60) return '$minutes min';
  final hours = minutes / 60;
  return hours == hours.roundToDouble() ? '${hours.toInt()} hr' : '${hours.toStringAsFixed(1)} hr';
}
