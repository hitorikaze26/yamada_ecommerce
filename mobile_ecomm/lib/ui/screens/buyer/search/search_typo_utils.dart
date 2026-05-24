/// Lightweight typo helper for “Did you mean…” suggestions.
int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  final row0 = List<int>.generate(b.length + 1, (i) => i);
  final row1 = List<int>.filled(b.length + 1, 0);
  for (var i = 0; i < a.length; i++) {
    row1[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      final cost = a[i] == b[j] ? 0 : 1;
      row1[j + 1] = [
        row1[j] + 1,
        row0[j + 1] + 1,
        row0[j] + cost,
      ].reduce((v, e) => e < v ? e : v);
    }
    for (var j = 0; j <= b.length; j++) {
      row0[j] = row1[j];
    }
  }
  return row0[b.length];
}

String? bestTypoMatch(String query, List<String> candidates, {int maxDistance = 2}) {
  if (query.trim().length < 2) return null;
  final q = query.toLowerCase().trim();
  String? best;
  var bestDist = maxDistance + 1;
  for (final c in candidates) {
    final t = c.toLowerCase();
    if (t == q) continue;
    final d = levenshtein(q, t);
    if (d < bestDist) {
      bestDist = d;
      best = c;
    }
  }
  return bestDist <= maxDistance ? best : null;
}
