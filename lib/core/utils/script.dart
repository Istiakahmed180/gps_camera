/// Wide letter spacing and capitals suit Latin headings but pull Bangla
/// (and other joined scripts) apart, so they are used only for Latin text.
bool isLatinText(String text) => !text.runes.any((r) => r > 0x024F);

/// Whether [text] has Arabic or Hebrew letters.
bool hasRtlLetters(String text) => text.runes.any(
  (r) =>
      (r >= 0x0590 && r <= 0x08FF) ||
      (r >= 0xFB1D && r <= 0xFDFF) ||
      (r >= 0xFE70 && r <= 0xFEFF),
);

/// A number, unit or Latin phrase such as `240° SW`, `±12 m` or
/// `23.91° N, 90.40° E`. Separators like `·` end a run, so list items
/// still follow the right-to-left order.
final _ltrRun = RegExp(
  r"[A-Za-z0-9±≈+\-−]([A-Za-z0-9°±≈+\-−.,:/()'#_% ]*[A-Za-z0-9°)%])?",
);

/// In right-to-left text, keeps each number, unit and Latin phrase in its
/// own left-to-right order, so `240° SW` does not turn into `SW °240`.
/// Display only: the added marks are invisible but are part of the string.
String keepLtrRuns(String text, {required bool rtl}) =>
    rtl ? text.replaceAllMapped(_ltrRun, (m) => '\u2066${m[0]}\u2069') : text;
