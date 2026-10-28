String two(int n) => n.toString().padLeft(2, '0');

/// YYYY-MM-DD from a DateTime (local).
String isoDate(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

/// Fallback when the server has not answered /api/health yet.
String localTodayIso() => isoDate(DateTime.now());

/// '2026-03-04' -> 'Mar 4, 2026'
String prettyDate(String? iso) {
  if (iso == null || iso.length < 10) return iso ?? '—';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(iso);
  if (m == null) return iso;
  final month = int.parse(m.group(2)!);
  if (month < 1 || month > 12) return iso;
  return '${months[month - 1]} ${int.parse(m.group(3)!)}, ${m.group(1)}';
}

String initials(String? name) {
  final parts = (name ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

extension _First on String {
  Iterable<String> get characters => split('');
}