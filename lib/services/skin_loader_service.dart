import 'dart:convert';
import 'dart:io';
import 'package:flutter/painting.dart';
import '../models/skin_theme.dart';

class SkinLoaderService {
  static Color parseHexColor(dynamic value, [Color fallback = const Color(0xFFFFFFFF)]) {
    if (value is String) {
      var hex = value.replaceAll('#', '').trim();
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        // #RRGGBBAA -> Flutter 0xAARRGGBB
        final rrggbb = hex.substring(0, 6);
        final aa = hex.substring(6, 8);
        return Color(int.parse('$aa$rrggbb', radix: 16));
      }
    } else if (value is Map && value['gradient'] is List && (value['gradient'] as List).isNotEmpty) {
      return parseHexColor((value['gradient'] as List).first, fallback);
    }
    return fallback;
  }

  static SkinTheme? parseSkinJson(String jsonString) {
    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      final id = map['id']?.toString() ?? 'custom_${DateTime.now().millisecondsSinceEpoch}';
      final name = map['name']?.toString() ?? 'Custom Skin';
      final description = map['description']?.toString() ?? 'Imported skin theme.';
      final author = map['author']?.toString() ?? 'Community';

      final surfaces = map['surfaces'] as Map<String, dynamic>? ?? {};
      final ink = map['ink'] as Map<String, dynamic>? ?? {};
      final metrics = map['metrics'] as Map<String, dynamic>? ?? {};
      final meters = map['meters'] as Map<String, dynamic>? ?? {};
      final channelsData = meters['channels'] as Map<String, dynamic>? ?? {};

      final winBg = parseHexColor(surfaces['window'], const Color(0xFF1E1E24));
      final winStroke = parseHexColor(surfaces['windowStroke'], const Color(0xFF383848));
      final headerBg = parseHexColor(surfaces['header'], const Color(0xFF18181E));
      final headerStroke = parseHexColor(surfaces['headerRule'] ?? surfaces['windowStroke'], const Color(0xFF282834));
      final tileBg = parseHexColor(surfaces['tile'], const Color(0xFF25252E));
      final tileStroke = parseHexColor(surfaces['tileStroke'], const Color(0xFF383848));

      final textPrimary = parseHexColor(ink['primary'] ?? ink['title'], const Color(0xFFF3F3F3));
      final textSecondary = parseHexColor(ink['secondary'], const Color(0xFFA0A0A8));
      final textAccent = parseHexColor(ink['badge'] ?? ink['title'], const Color(0xFF60CDFF));

      final cornerRadius = (metrics['cornerRadius'] as num?)?.toDouble() ?? 8.0;
      final tileCornerRadius = (metrics['tileCornerRadius'] as num?)?.toDouble() ?? 6.0;

      final styleStr = meters['style']?.toString();
      final meterStyle = styleStr == 'graph'
          ? MeterStyle.graph
          : (styleStr == 'rows' ? MeterStyle.segmented : MeterStyle.segmented);

      final channels = <String, ChannelColor>{};
      for (final key in ['cpu', 'memory', 'disk', 'network', 'gpu', 'thermal', 'power', 'alert']) {
        final ch = channelsData[key] as Map<String, dynamic>?;
        if (ch != null) {
          final accent = parseHexColor(ch['accent'], textAccent);
          final lit = parseHexColor(ch['lit'], accent);
          final unlit = parseHexColor(ch['unlit'], accent.withValues(alpha: 0.25));
          channels[key] = ChannelColor(accent: accent, lit: lit, unlit: unlit);
        } else {
          channels[key] = ChannelColor(
            accent: textAccent,
            lit: textAccent,
            unlit: textAccent.withValues(alpha: 0.2),
          );
        }
      }

      return SkinTheme(
        id: id,
        name: name,
        description: description,
        author: author,
        windowBackground: winBg,
        windowStroke: winStroke,
        headerBackground: headerBg,
        headerStroke: headerStroke,
        tileBackground: tileBg,
        tileStroke: tileStroke,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        textAccent: textAccent,
        cornerRadius: cornerRadius,
        tileCornerRadius: tileCornerRadius,
        defaultMeterStyle: meterStyle,
        channels: channels,
      );
    } catch (_) {
      return null;
    }
  }

  static List<SkinTheme> loadLocalSkins([String skinsDirPath = 'skins']) {
    final list = <SkinTheme>[];
    try {
      final dir = Directory(skinsDirPath);
      if (!dir.existsSync()) return list;

      for (final entity in dir.listSync()) {
        if (entity is File && (entity.path.endsWith('.taskmanskin') || entity.path.endsWith('.tmogskin'))) {
          final content = entity.readAsStringSync();
          final parsed = parseSkinJson(content);
          if (parsed != null) list.add(parsed);
        } else if (entity is Directory && (entity.path.endsWith('.taskmanskin') || entity.path.endsWith('.tmogskin'))) {
          final skinFile = File('${entity.path}/skin.json');
          if (skinFile.existsSync()) {
            final content = skinFile.readAsStringSync();
            final parsed = parseSkinJson(content);
            if (parsed != null) list.add(parsed);
          }
        }
      }
    } catch (_) {}
    return list;
  }
}
