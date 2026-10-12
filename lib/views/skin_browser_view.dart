import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import '../models/skin_theme.dart';
import '../providers/taskman_provider.dart';

class SkinBrowserView extends StatelessWidget {
  const SkinBrowserView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskManProvider>();
    final currentSkin = provider.currentSkin;
    final skins = provider.availableSkins;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Theme & Skin Gallery',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: currentSkin.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Loaded ${skins.length} skins from builtin sets and local skin theme files in /skins.',
                    style: TextStyle(
                      fontSize: 12,
                      color: currentSkin.textSecondary,
                    ),
                  ),
                ],
              ),
              Button(
                onPressed: () => provider.setSkin(SkinTheme.builtInSkins[0]),
                child: const Row(
                  children: [
                    Icon(FluentIcons.reset, size: 12),
                    SizedBox(width: 6),
                    Text('Reset Default'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.1,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: skins.length,
              itemBuilder: (context, index) {
                final skin = skins[index];
                final isSelected = skin.id == currentSkin.id;

                return GestureDetector(
                  onTap: () => provider.setSkin(skin),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: skin.windowBackground,
                      borderRadius: BorderRadius.circular(skin.cornerRadius),
                      border: Border.all(
                        color: isSelected ? skin.textAccent : skin.windowStroke,
                        width: isSelected ? 2.0 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: skin.textAccent.withValues(alpha: 0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              skin.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: skin.textPrimary,
                              ),
                            ),
                            if (isSelected)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: skin.textAccent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Author: ${skin.author}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: skin.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Text(
                            skin.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: skin.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _dot(skin.getChannel('cpu').accent),
                            _dot(skin.getChannel('memory').accent),
                            _dot(skin.getChannel('disk').accent),
                            _dot(skin.getChannel('network').accent),
                            const Spacer(),
                            Text(
                              skin.defaultMeterStyle == MeterStyle.segmented
                                  ? 'LED Meters'
                                  : 'Wave Traces',
                              style: TextStyle(
                                fontSize: 10,
                                fontFamily: 'Consolas',
                                color: skin.textAccent,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
