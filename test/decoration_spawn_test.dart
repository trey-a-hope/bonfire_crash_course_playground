import 'dart:convert';
import 'dart:io';

import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // game_screen.dart places the decorations on these tiles of row 7. Each
  // must be open with ground right below, so the decoration rests on the
  // ground instead of floating or sitting inside a wall. If the map changes,
  // this tells you to pick new tiles.
  test('decoration tiles sit right on top of the ground', () {
    final map = jsonDecode(File('assets/images/$MAP_ONE').readAsStringSync())
        as Map<String, dynamic>;
    final solid = <(int, int)>{
      for (final layer in map['layers'] as List)
        if (layer['collider'] == true)
          for (final tile in layer['tiles'] as List)
            (tile['x'] as int, tile['y'] as int),
    };

    const tiles = {
      'sign': (1, 7),
      'campfire': (12, 7),
      'mushrooms': (16, 7),
      'chest': (18, 7),
      'brass key': (10, 5),
      'spikes': (7, 7),
    };
    for (final MapEntry(key: name, value: (x, y)) in tiles.entries) {
      expect(solid, isNot(contains((x, y))), reason: '$name tile is open');
      expect(solid, contains((x, y + 1)), reason: 'ground under the $name');
    }
  });
}
