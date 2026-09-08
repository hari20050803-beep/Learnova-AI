/// Formats a date like "12/6/2026 • 13:05" without extra packages.
String formatDateTime(DateTime d) {
  final String hour = d.hour.toString().padLeft(2, '0');
  final String minute = d.minute.toString().padLeft(2, '0');
  return '${d.day}/${d.month}/${d.year} • $hour:$minute';
}
