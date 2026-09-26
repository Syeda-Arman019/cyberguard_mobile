/// Safe, bounded URL preprocessing for security analysis.
///
/// Produces a normalized/decoded view of a URL that the RiskEngine can use
/// for heuristic analysis. The ORIGINAL URL is never modified — it remains
/// the value stored in history, shown in the ResultCard, and carried on
/// notifications. Only the [PreprocessedUrl.analyzed] text may differ.
///
/// Decoding is deliberately bounded:
///  - at most [maxDecodePasses] passes (defeats double-encoding without
///    allowing infinite recursion),
///  - stops if the text exceeds [maxAnalyzedLength],
///  - malformed percent-escapes are left as-is (per-pass try/catch).
class PreprocessedUrl {
  /// The URL exactly as received. Always used for display/history.
  final String original;

  /// Original with ONLY the scheme + host lowercased. Path/query preserved.
  final String normalized;

  /// Bounded-decoded [normalized] — for SECURITY ANALYSIS ONLY.
  final String analyzed;

  /// Lowercased hostname from the parsed URL ('' when unparseable).
  final String host;

  /// True when the raw URL contained percent-escapes in path/query.
  final bool percentEncoded;

  /// True when a double percent-encoding was detected (e.g. `%252e`).
  final bool doubleEncoded;

  /// True when the raw URL contained an encoded traversal form (`%2e%2e`).
  final bool encodedTraversal;

  /// True when any hostname label uses punycode (`xn--`), which can hide
  /// homoglyph (look-alike character) domains.
  final bool hasPunycodeHost;

  const PreprocessedUrl({
    required this.original,
    required this.normalized,
    required this.analyzed,
    required this.host,
    required this.percentEncoded,
    required this.doubleEncoded,
    required this.encodedTraversal,
    required this.hasPunycodeHost,
  });

  static const int maxDecodePasses = 2;
  static const int maxAnalyzedLength = 2048;

  static final _hexEscape = RegExp(r'%[0-9a-fA-F]{2}');
  static final _doubleEscape = RegExp(r'%25[0-9a-fA-F]{2}');
  static final _encodedTraversal =
      RegExp(r'%2e%2e|%2e\.|\.%2e|%252e', caseSensitive: false);

  /// Processes [raw] without throwing: unparseable input degrades to a
  /// PreprocessedUrl whose analyzed text equals the trimmed original.
  static PreprocessedUrl process(String raw) {
    final original = raw.trim();
    var normalized = original;
    var host = '';

    try {
      final hasScheme = original.contains('://');
      final uri = Uri.parse(hasScheme ? original : 'http://$original');
      host = uri.host.toLowerCase();

      // Lowercase scheme + host only; keep path/query exactly as sent.
      if (hasScheme) {
        final schemeEnd = original.indexOf('://') + 3;
        var hostEnd = schemeEnd;
        while (hostEnd < original.length) {
          final c = original[hostEnd];
          if (c == '/' || c == '?' || c == '#') break;
          hostEnd++;
        }
        normalized = original.substring(0, schemeEnd) +
            original.substring(schemeEnd, hostEnd).toLowerCase() +
            original.substring(hostEnd);
      }
    } catch (_) {
      // Keep original text; analysis continues on the raw string.
    }

    final percentEncoded = _hexEscape.hasMatch(normalized);
    final doubleEncoded = _doubleEscape.hasMatch(normalized);
    final encodedTraversal = _encodedTraversal.hasMatch(normalized);
    final hasPunycodeHost =
        host.split('.').any((label) => label.startsWith('xn--'));

    // Bounded decoding: normalize + decode up to maxDecodePasses times so
    // `%6C%6F%67%69%6E` -> `login` and `%252e%252e` -> `..` are both seen.
    var analyzed = normalized;
    for (var pass = 0; pass < maxDecodePasses; pass++) {
      if (analyzed.length > maxAnalyzedLength) break;
      if (!_hexEscape.hasMatch(analyzed)) break;
      final decoded = _safeDecode(analyzed);
      if (decoded == analyzed) break;
      analyzed = decoded;
    }
    if (analyzed.length > maxAnalyzedLength) {
      analyzed = analyzed.substring(0, maxAnalyzedLength);
    }

    return PreprocessedUrl(
      original: original,
      normalized: normalized,
      analyzed: analyzed,
      host: host,
      percentEncoded: percentEncoded,
      doubleEncoded: doubleEncoded,
      encodedTraversal: encodedTraversal,
      hasPunycodeHost: hasPunycodeHost,
    );
  }

  static String _safeDecode(String input) {
    try {
      return Uri.decodeFull(input);
    } catch (_) {
      return input; // Malformed escape — leave this pass unchanged.
    }
  }
}
