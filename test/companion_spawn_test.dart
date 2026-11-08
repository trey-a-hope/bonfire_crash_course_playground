import 'dart:convert';
import 'dart:io';

import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // game_screen.dart spawns the companion at tile (24, 7) so it starts on
  // the ground, on a flat stretch it can follow the hero across. If the map
  // changes, this tells you to pick a new tile.
  test('companion spawn tile sits right on top of the ground', () {
    final map = jsonDecode(File('assets/images/$MAP_ONE').readAsStringSync())
        as Map<String, dynamic>;
    final solid = <(int, int)>{
      for (final layer in map['layers'] as List)
        if (layer['collider'] == true)
          for (final tile in layer['tiles'] as List)
            (tile['x'] as int, tile['y'] as int),
    };

    expect(map['tileSize'], TILE_SIZE);
    expect(solid, contains((24, 8)), reason: 'ground under the companion');
    // Columns 23-29 of row 7 are open with ground below: room to walk
    // after the hero.
    for (var x = 23; x <= 29; x++) {
      expect(solid, isNot(contains((x, 7))), reason: 'open at column $x');
      expect(solid, contains((x, 8)), reason: 'ground at column $x');
    }
  });
}
