import 'dart:io';
import 'dart:typed_data';

import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reads a PNG's width and height from its header.
(int, int) _pngSize(String path) {
  final bytes = File('assets/images/$path').readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  return (data.getUint32(16), data.getUint32(20));
}

void main() {
  // Companion.dart slices these sheets into 32x32 frames, so the frame
  // counts it passes to AnimationUtils must match the art.
  test('strawberry sheets match the frame counts the companion uses', () {
    expect(_pngSize(STRAWBERRY_IDLE), (8 * 32, 32));
    expect(_pngSize(STRAWBERRY_WALK), (4 * 32, 32));
    expect(_pngSize(STRAWBERRY_TALK), (2 * 32, 32));
    expect(_pngSize(STRAWBERRY_WAVE), (6 * 32, 32));
    expect(_pngSize(STRAWBERRY_JUMP), (4 * 32, 32));
    expect(_pngSize(STRAWBERRY_ATTACK), (5 * 32, 32));
    expect(_pngSize(STRAWBERRY_HURT), (5 * 32, 32));
    expect(_pngSize(STRAWBERRY_DEATH), (4 * 32, 32));
  });
}
