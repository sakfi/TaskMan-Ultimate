import 'package:flutter/painting.dart';

enum MeterStyle {
  segmented,
  graph,
  numeric,
}

class ChannelColor {
  final Color accent;
  final Color lit;
  final Color unlit;

  const ChannelColor({
    required this.accent,
    required this.lit,
    required this.unlit,
  });
}

class SkinTheme {
  final String id;
  final String name;
  final String description;
  final String author;
  final Color windowBackground;
  final Color windowStroke;
  final Color headerBackground;
  final Color headerStroke;
  final Color tileBackground;
  final Color tileStroke;
  final Color textPrimary;
  final Color textSecondary;
  final Color textAccent;
  final double cornerRadius;
  final double tileCornerRadius;
  final MeterStyle defaultMeterStyle;
  final Map<String, ChannelColor> channels;

  const SkinTheme({
    required this.id,
    required this.name,
    required this.description,
    required this.author,
    required this.windowBackground,
    required this.windowStroke,
    required this.headerBackground,
    required this.headerStroke,
    required this.tileBackground,
    required this.tileStroke,
    required this.textPrimary,
    required this.textSecondary,
    required this.textAccent,
    required this.cornerRadius,
    required this.tileCornerRadius,
    required this.defaultMeterStyle,
    required this.channels,
  });

  ChannelColor getChannel(String key) {
    return channels[key] ??
        const ChannelColor(
          accent: Color(0xFF00FF00),
          lit: Color(0xFF00FF00),
          unlit: Color(0xFF003300),
        );
  }

  Color get cpuColor => getChannel('cpu').lit;
  Color get kernelColor => getChannel('kernel').lit;
  Color get memoryColor => getChannel('memory').lit;
  Color get diskColor => getChannel('disk').lit;
  Color get networkColor => getChannel('network').lit;
  Color get unlitChannelColor => getChannel('cpu').unlit;

  // Pre-configured Built-in & Modern skins
  static final List<SkinTheme> builtInSkins = [
    // 1. Modern Fluent Windows 11
    SkinTheme(
      id: 'fluent_dark',
      name: 'Windows 11 Fluent (Dark)',
      description: 'Modern Windows 11 Mica shell with refined accent colors.',
      author: 'TaskMan Team',
      windowBackground: const Color(0xFF1E1E24),
      windowStroke: const Color(0xFF33333F),
      headerBackground: const Color(0xFF18181E),
      headerStroke: const Color(0xFF282834),
      tileBackground: const Color(0xFF25252E),
      tileStroke: const Color(0xFF383848),
      textPrimary: const Color(0xFFF3F3F3),
      textSecondary: const Color(0xFFA0A0A8),
      textAccent: const Color(0xFF60CDFF),
      cornerRadius: 10.0,
      tileCornerRadius: 8.0,
      defaultMeterStyle: MeterStyle.graph,
      channels: {
        'cpu': const ChannelColor(
          accent: Color(0xFF60CDFF),
          lit: Color(0xFF60CDFF),
          unlit: Color(0xFF1B3D4D),
        ),
        'memory': const ChannelColor(
          accent: Color(0xFFB180F0),
          lit: Color(0xFFB180F0),
          unlit: Color(0xFF352054),
        ),
        'disk': const ChannelColor(
          accent: Color(0xFF6CCB5F),
          lit: Color(0xFF6CCB5F),
          unlit: Color(0xFF1B3E19),
        ),
        'network': const ChannelColor(
          accent: Color(0xFFFFB900),
          lit: Color(0xFFFFB900),
          unlit: Color(0xFF4C3600),
        ),
        'gpu': const ChannelColor(
          accent: Color(0xFFFF6978),
          lit: Color(0xFFFF6978),
          unlit: Color(0xFF4E1B21),
        ),
      },
    ),

    // 2. Classic Windows Task Manager
    SkinTheme(
      id: 'wintaskman_classic',
      name: 'Windows NT/95 Classic',
      description: 'Grey 3D chrome, navy header, etched tiles, and green-on-black segmented LED meters.',
      author: 'TaskMan Team',
      windowBackground: const Color(0xFFD4D0C8),
      windowStroke: const Color(0xFF808080),
      headerBackground: const Color(0xFF000080),
      headerStroke: const Color(0xFFFFFFFF),
      tileBackground: const Color(0xFF000000),
      tileStroke: const Color(0xFF808080),
      textPrimary: const Color(0xFF000000),
      textSecondary: const Color(0xFF404040),
      textAccent: const Color(0xFF00FF00),
      cornerRadius: 0.0,
      tileCornerRadius: 0.0,
      defaultMeterStyle: MeterStyle.segmented,
      channels: {
        'cpu': const ChannelColor(
          accent: Color(0xFF00FF00),
          lit: Color(0xFF00FF00),
          unlit: Color(0xFF004400),
        ),
        'memory': const ChannelColor(
          accent: Color(0xFF00FF00),
          lit: Color(0xFF00FF00),
          unlit: Color(0xFF004400),
        ),
        'disk': const ChannelColor(
          accent: Color(0xFF00FF00),
          lit: Color(0xFF00FF00),
          unlit: Color(0xFF004400),
        ),
        'network': const ChannelColor(
          accent: Color(0xFF00FF00),
          lit: Color(0xFF00FF00),
          unlit: Color(0xFF004400),
        ),
        'gpu': const ChannelColor(
          accent: Color(0xFF00FF00),
          lit: Color(0xFF00FF00),
          unlit: Color(0xFF004400),
        ),
      },
    ),

    // 3. Winamp Retro
    SkinTheme(
      id: 'winamp',
      name: 'Winamp Equalizer',
      description: 'Black display panels, yellow fixed-width readouts, and neon audio equalizer bars.',
      author: 'TaskMan Team',
      windowBackground: const Color(0xFF36323B),
      windowStroke: const Color(0xFF8F9199),
      headerBackground: const Color(0xFF0F0E10),
      headerStroke: const Color(0xFF535159),
      tileBackground: const Color(0xFF070607),
      tileStroke: const Color(0xFF535159),
      textPrimary: const Color(0xFFE4DF6A),
      textSecondary: const Color(0xFF98873D),
      textAccent: const Color(0xFF1AFF1C),
      cornerRadius: 0.0,
      tileCornerRadius: 0.0,
      defaultMeterStyle: MeterStyle.segmented,
      channels: {
        'cpu': const ChannelColor(
          accent: Color(0xFF1AFF1C),
          lit: Color(0xFF1AFF1C),
          unlit: Color(0xFF0E3E0E),
        ),
        'memory': const ChannelColor(
          accent: Color(0xFFE4DF6A),
          lit: Color(0xFFE4DF6A),
          unlit: Color(0xFF3D3B18),
        ),
        'disk': const ChannelColor(
          accent: Color(0xFF1AFF1C),
          lit: Color(0xFF1AFF1C),
          unlit: Color(0xFF0E3E0E),
        ),
        'network': const ChannelColor(
          accent: Color(0xFFE4DF6A),
          lit: Color(0xFFE4DF6A),
          unlit: Color(0xFF3D3B18),
        ),
        'gpu': const ChannelColor(
          accent: Color(0xFF00C400),
          lit: Color(0xFF00C400),
          unlit: Color(0xFF083108),
        ),
      },
    ),

    // 4. Traces / Cyberpunk
    SkinTheme(
      id: 'traces',
      name: 'Traces (Oscilloscope)',
      description: 'Scrolling history wave graphs, deep obsidian surfaces and neon cyan/magenta traces.',
      author: 'TaskMan Team',
      windowBackground: const Color(0xFF0A0D10),
      windowStroke: const Color(0xFF43505C),
      headerBackground: const Color(0xFF141A20),
      headerStroke: const Color(0xFF43505C),
      tileBackground: const Color(0xFF070A0D),
      tileStroke: const Color(0xFF232D38),
      textPrimary: const Color(0xFFE6EDF3),
      textSecondary: const Color(0xFF7D8B99),
      textAccent: const Color(0xFF4FD1C5),
      cornerRadius: 12.0,
      tileCornerRadius: 8.0,
      defaultMeterStyle: MeterStyle.graph,
      channels: {
        'cpu': const ChannelColor(
          accent: Color(0xFF4FD1C5),
          lit: Color(0xFF4FD1C5),
          unlit: Color(0xFF123431),
        ),
        'memory': const ChannelColor(
          accent: Color(0xFFD48CFF),
          lit: Color(0xFFD48CFF),
          unlit: Color(0xFF381B4C),
        ),
        'disk': const ChannelColor(
          accent: Color(0xFF7BE08A),
          lit: Color(0xFF7BE08A),
          unlit: Color(0xFF18381D),
        ),
        'network': const ChannelColor(
          accent: Color(0xFF7FB2F0),
          lit: Color(0xFF7FB2F0),
          unlit: Color(0xFF182E47),
        ),
        'gpu': const ChannelColor(
          accent: Color(0xFFFFB454),
          lit: Color(0xFFFFB454),
          unlit: Color(0xFF4B310F),
        ),
      },
    ),

    // 5. Windows Media Player
    SkinTheme(
      id: 'media_player',
      name: 'Windows Media Player',
      description: 'Glossy deep blue chrome with crisp ice-blue readouts.',
      author: 'TaskMan Team',
      windowBackground: const Color(0xFF091C36),
      windowStroke: const Color(0xFF8FBEF5),
      headerBackground: const Color(0xFF1B5FB2),
      headerStroke: const Color(0xFF8FBEF5),
      tileBackground: const Color(0xFF051325),
      tileStroke: const Color(0xFF2B4D77),
      textPrimary: const Color(0xFFFFFFFF),
      textSecondary: const Color(0xFFBFD8FF),
      textAccent: const Color(0xFF8FE0FF),
      cornerRadius: 10.0,
      tileCornerRadius: 6.0,
      defaultMeterStyle: MeterStyle.segmented,
      channels: {
        'cpu': const ChannelColor(
          accent: Color(0xFF8FE0FF),
          lit: Color(0xFF8FE0FF),
          unlit: Color(0xFF0B2946),
        ),
        'memory': const ChannelColor(
          accent: Color(0xFFC0A8FF),
          lit: Color(0xFFC0A8FF),
          unlit: Color(0xFF1A1440),
        ),
        'disk': const ChannelColor(
          accent: Color(0xFF9BE8A0),
          lit: Color(0xFF9BE8A0),
          unlit: Color(0xFF123414),
        ),
        'network': const ChannelColor(
          accent: Color(0xFF8FE0FF),
          lit: Color(0xFF8FE0FF),
          unlit: Color(0xFF0B2946),
        ),
        'gpu': const ChannelColor(
          accent: Color(0xFF5FC8F5),
          lit: Color(0xFF5FC8F5),
          unlit: Color(0xFF07253A),
        ),
      },
    ),
  ];
}
