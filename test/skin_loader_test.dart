import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskman_ultimate/services/skin_loader_service.dart';

void main() {
  group('SkinLoaderService', () {
    test('parseHexColor handles 6-digit and 8-digit hex colors', () {
      final color6 = SkinLoaderService.parseHexColor('#FF00AA');
      expect(color6, equals(const Color(0xFFFF00AA)));

      final color8 = SkinLoaderService.parseHexColor('#11223380');
      // #RRGGBBAA -> 0x80112233
      expect(color8, equals(const Color(0x80112233)));
    });

    test('parseHexColor falls back gracefully on invalid input', () {
      final fallback = const Color(0xFF123456);
      expect(SkinLoaderService.parseHexColor('invalid', fallback), equals(fallback));
      expect(SkinLoaderService.parseHexColor(null, fallback), equals(fallback));
    });

    test('parseSkinJson parses skin JSON successfully', () {
      const skinJson = '''
      {
        "id": "cyberpunk_neon",
        "name": "Cyberpunk Neon",
        "description": "High contrast cyber theme",
        "author": "Antigravity",
        "surfaces": {
          "window": "#0F0F14",
          "windowStroke": "#00FFCC",
          "header": "#15151C",
          "tile": "#1A1A24"
        },
        "ink": {
          "primary": "#FFFFFF",
          "secondary": "#A0A0A8",
          "badge": "#00FFCC"
        },
        "metrics": {
          "cornerRadius": 12.0
        },
        "meters": {
          "style": "graph"
        }
      }
      ''';

      final skin = SkinLoaderService.parseSkinJson(skinJson);
      expect(skin, isNotNull);
      expect(skin!.id, equals('cyberpunk_neon'));
      expect(skin.name, equals('Cyberpunk Neon'));
      expect(skin.windowBackground, equals(const Color(0xFF0F0F14)));
      expect(skin.windowStroke, equals(const Color(0xFF00FFCC)));
      expect(skin.cornerRadius, equals(12.0));
      expect(skin.textAccent, equals(const Color(0xFF00FFCC)));
    });

    test('parseSkinJson returns null on invalid JSON format', () {
      final skin = SkinLoaderService.parseSkinJson('{ invalid json: ');
      expect(skin, isNull);
    });
  });
}
