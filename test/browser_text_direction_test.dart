import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:net_flow/browser/services/browser_text_direction.dart';

void main() {
  test('uses RTL alignment for Hebrew search text', () {
    final direction = BrowserTextDirection.resolve('בדיקת נטפרי');

    expect(direction.textDirection, TextDirection.rtl);
    expect(direction.textAlign, TextAlign.right);
  });

  test('uses LTR alignment for URLs and English search text', () {
    expect(
      BrowserTextDirection.resolve('https://example.com').textDirection,
      TextDirection.ltr,
    );
    expect(
      BrowserTextDirection.resolve('example.com').textAlign,
      TextAlign.left,
    );
    expect(
      BrowserTextDirection.resolve('netfree search').textDirection,
      TextDirection.ltr,
    );
  });
}
