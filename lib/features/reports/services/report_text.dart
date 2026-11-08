import 'dart:typed_data';

/// Text the PDF library cannot draw itself (it does not join Bangla,
/// Hindi or Arabic letters), to be drawn by Flutter and placed as an image.
/// Plain data, so it can be sent between isolates.
class TextRequest {
  const TextRequest({
    required this.text,
    required this.fontSize,
    required this.weight,
    required this.color,
    required this.letterSpacing,
    required this.maxWidth,
    required this.maxLines,
    required this.rtl,
    required this.center,
  });

  final String text;

  /// In PDF points.
  final double fontSize;

  /// 400, 500 or 700.
  final int weight;

  /// ARGB.
  final int color;
  final double letterSpacing;

  /// In PDF points.
  final double maxWidth;
  final int? maxLines;
  final bool rtl;
  final bool center;

  @override
  bool operator ==(Object other) =>
      other is TextRequest &&
      other.text == text &&
      other.fontSize == fontSize &&
      other.weight == weight &&
      other.color == color &&
      other.letterSpacing == letterSpacing &&
      other.maxWidth == maxWidth &&
      other.maxLines == maxLines &&
      other.rtl == rtl &&
      other.center == center;

  @override
  int get hashCode => Object.hash(
    text,
    fontSize,
    weight,
    color,
    letterSpacing,
    maxWidth,
    maxLines,
    rtl,
    center,
  );
}

/// A drawn [TextRequest]: a PNG and its size in PDF points.
class ShapedText {
  const ShapedText(this.png, this.width, this.height, {this.inset = 0});

  final Uint8List png;
  final double width;
  final double height;

  /// Blank margin on each side of the text, so marks that reach past the
  /// text box (like the Bangla ি) are not cut off. The image is shifted by
  /// it so the text itself lines up.
  final double inset;
}

/// Draws the texts, in order; null where one could not be drawn.
typedef TextShaper = Future<List<ShapedText?>> Function(
  List<TextRequest> requests,
);

/// Whether [text] has letters the PDF library cannot shape: anything past
/// Latin, Greek and Cyrillic, except punctuation and symbols (° ± − · …).
bool needsShaping(String text) => text.runes.any(
  (r) => r >= 0x0590 && (r < 0x2000 || r > 0x2BFF) && r != 0xFEFF,
);
