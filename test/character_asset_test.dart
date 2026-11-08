import 'dart:io';
import 'dart:typed_data';

import 'package:bonfire_crash_course_playground/core/constants/character_asset.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reads a PNG's width and height from its header.
(int, int) _pngSize(String path) {
  final bytes = File('assets/images/$path').readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  return (data.getUint32(16), data.getUint32(20));
}

void main() {
  for (final asset in CharacterAsset.values) {
    group(asset.id, () {
      void expectSheet(String path, int frames, {int frameSize = 32}) {
        expect(File('assets/images/$path').existsSync(), isTrue,
            reason: '$path is missing');
        expect(_pngSize(path), (frames * frameSize, frameSize),
            reason: '$path should be $frames frames of ${frameSize}px');
      }

      test('melee attack sheets match the frame count', () {
        expectSheet(asset.attackMeleeLeft, asset.attackMeleeFrames);
        expectSheet(asset.attackMeleeRight, asset.attackMeleeFrames);
      });

      test('range attack sheets match the frame count', () {
        expectSheet(asset.attackRangeLeft, asset.attackRangeFrames);
        expectSheet(asset.attackRangeRight, asset.attackRangeFrames);
      });

      test('range release frame is inside the range sheet', () {
        expect(asset.attackRangeReleaseFrame,
            inInclusiveRange(1, asset.attackRangeFrames));
      });

      test('hurt sheets match the frame count', () {
        expectSheet(asset.hurtLeft, asset.hurtFrames);
        expectSheet(asset.hurtRight, asset.hurtFrames);
      });

      test('projectile sheets are 4 frames of 16px', () {
        expectSheet(asset.projectileLeft, 4, frameSize: 16);
        expectSheet(asset.projectileRight, 4, frameSize: 16);
      });

      test('death sheets match the frame count', () {
        expectSheet(asset.deathLeft, asset.deathFrames);
        expectSheet(asset.deathRight, asset.deathFrames);
      });
    });
  }
}
