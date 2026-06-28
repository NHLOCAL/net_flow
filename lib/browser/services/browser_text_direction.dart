import 'package:flutter/widgets.dart';

class BrowserResolvedTextDirection {
  const BrowserResolvedTextDirection({
    required this.textDirection,
    required this.textAlign,
  });

  final TextDirection textDirection;
  final TextAlign textAlign;

  @override
  bool operator ==(Object other) {
    return other is BrowserResolvedTextDirection &&
        other.textDirection == textDirection &&
        other.textAlign == textAlign;
  }

  @override
  int get hashCode => Object.hash(textDirection, textAlign);
}

class BrowserTextDirection {
  const BrowserTextDirection._();

  static const rtl = BrowserResolvedTextDirection(
    textDirection: TextDirection.rtl,
    textAlign: TextAlign.right,
  );

  static const ltr = BrowserResolvedTextDirection(
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.left,
  );

  static BrowserResolvedTextDirection resolve(String value) {
    for (final rune in value.trimLeft().runes) {
      if (_isRtlStrong(rune)) {
        return rtl;
      }
      if (_isLtrStrong(rune)) {
        return ltr;
      }
    }
    return rtl;
  }

  static bool _isRtlStrong(int rune) {
    return (rune >= 0x0590 && rune <= 0x08FF) ||
        (rune >= 0xFB1D && rune <= 0xFEFC);
  }

  static bool _isLtrStrong(int rune) {
    return (rune >= 0x0030 && rune <= 0x0039) ||
        (rune >= 0x0041 && rune <= 0x005A) ||
        (rune >= 0x0061 && rune <= 0x007A);
  }
}
