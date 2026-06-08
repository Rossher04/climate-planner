DateTime? parseSimpleDate(String date) {
  final parts = date.split('/');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}

String toApiDate(String date) {
  final parts = date.split('/');
  if (parts.length != 3) return date;
  return '${parts[2]}-${parts[1]}-${parts[0]}';
}

String fromApiDate(String date) {
  final parts = date.split('-');
  if (parts.length != 3) return date;
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}

String shortTime(String time) => time.length >= 5 ? time.substring(0, 5) : time;
