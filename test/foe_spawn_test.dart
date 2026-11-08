import 'dart:convert';
import 'dart:io';

import 'package:bonfire_crash_course_playground/core/constants/globals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // game_screen.dart spawns the foe at tile (28, 7) so it starts on the
  // ground, to the right of the companion. If the map changes, this tells
  // you to pick a new tile.
  test('foe spawn tile sits right on top of the ground', () {
    final map = jsonDecode(File('assets/images/$MAP_ONE').readAsStringSync())
        as Map<String, dynamic>;
    final solid = <(int, int)>{
      for (final layer in map['layers'] as List)
        if (layer['collider'] == true)
          for (final tile in layer['tiles'] as List)
            (tile['x'] as int, tile['y'] as int),
    };

    expect(map['tileSize'], TILE_SIZE);
    expect(solid, isNot(contains((28, 7))), reason: 'open at the foe');
    expect(solid, contains((28, 8)), reason: 'ground under the foe');
  });

  // game_screen.dart spawns the lizardfolk warrior on map 02 at tile
  // (23, 7) and lets it pace between columns 21 and 28. It needs ground
  // under every tile of that walk and a free tile above it.
  test('lizardfolk spawn and patrol sit on open ground in map 02', () {
    final map = jsonDecode(File('assets/images/$MAP_TWO').readAsStringSync())
        as Map<String, dynamic>;
    final solid = <(int, int)>{
      for (final layer in map['layers'] as List)
        if (layer['collider'] == true)
          for (final tile in layer['tiles'] as List)
            (tile['x'] as int, tile['y'] as int),
    };

    expect(map['tileSize'], TILE_SIZE);
    for (var x = 21; x <= 28; x++) {
      expect(solid, isNot(contains((x, 7))), reason: 'open at column $x');
      expect(solid, contains((x, 8)), reason: 'ground under column $x');
    }
  });
}
