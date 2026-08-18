import 'package:flutter/material.dart';
import 'package:flutter_application_mhproj/models/companion.dart';
import 'package:flutter_application_mhproj/features/companions/presentation/widgets/sticker_rail.dart';

class GardenOverlay extends StatelessWidget {
  const GardenOverlay({
    super.key,
    required this.companion,
    required this.leaves,
    required this.stickers,
    required this.challengeCopy,
    required this.challengeCompleted,
    required this.onCompleteChallenge,
    required this.onStartBreathing,
    required this.plantGrowth,
    required this.unlockedPlants,
    required this.activePlantId,
    required this.onPlantSelect,
    required this.onPlantGrowth,
  });

  final Companion companion;
  final int leaves;
  final List<String> stickers;
  final String challengeCopy;
  final bool challengeCompleted;
  final Future<bool> Function() onCompleteChallenge;
  final Future<bool> Function() onStartBreathing;
  final Map<String, int> plantGrowth;
  final List<String> unlockedPlants;
  final String activePlantId;
  final ValueChanged<String> onPlantSelect;
  final ValueChanged<int> onPlantGrowth;

  Future<void> _handleChallenge() async {
    if (challengeCompleted) return;
    await onCompleteChallenge();
  }

  Future<void> _handleBreathing() async {
    await onStartBreathing();
  }

  GardenPlant get _currentPlant => GardenPlant.all.firstWhere(
    (plant) => plant.id == activePlantId,
    orElse: () => GardenPlant.all.first,
  );

  int get _plantProgressForActive => plantGrowth[activePlantId] ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emotion Garden')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _PixelPlantDisplay(
              plant: _currentPlant,
              progress: _plantProgressForActive,
              primaryColor: companion.primaryColor,
            ),
            const SizedBox(height: 24),
            _PlantSelector(
              plants: GardenPlant.all,
              activeId: activePlantId,
              growth: plantGrowth,
              unlockedPlants: unlockedPlants,
              leaves: leaves,
              onSelect: onPlantSelect,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.spa_outlined),
              title: const Text('Gentle challenge of the day'),
              subtitle: Text(challengeCopy),
              trailing: challengeCompleted
                  ? const _SupportTag(
                      icon: Icons.verified_outlined,
                      label: 'Completed',
                      color: Colors.green,
                    )
                  : FilledButton(
                      onPressed: _handleChallenge,
                      child: const Text('Complete'),
                    ),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.self_improvement),
              title: const Text('Do a 1-minute breath'),
              subtitle: const Text('Earn 2 leaves when you finish'),
              trailing: FilledButton(
                onPressed: _handleBreathing,
                child: const Text('Start'),
              ),
            ),
            const Divider(),
            if (stickers.isNotEmpty) ...[
              const Text(
                'Stickers you have earned',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              StickerRail(stickers: stickers, companion: companion),
              const SizedBox(height: 16),
            ],
            const Text(
              'Each share, breathing practice, or gentle challenge adds leaves to unlock calmer scenes.',
            ),
          ],
        ),
      ),
    );
  }
}

class _PixelPlantDisplay extends StatelessWidget {
  const _PixelPlantDisplay({
    required this.plant,
    required this.progress,
    required this.primaryColor,
  });

  final GardenPlant plant;
  final int progress;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    final int stageIndex = plant.stageIndex(progress);
    final String stageLabel = plant.stageLabel(stageIndex);
    final double growthPercent = (progress / plant.totalGrowth).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 160,
            width: 160,
            child: CustomPaint(
              painter: _PixelPlantPainter(
                plant: plant,
                stage: stageIndex,
                color: primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            plant.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          Text(
            stageLabel,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: primaryColor.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: growthPercent,
              minHeight: 12,
              backgroundColor: Colors.white.withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$progress / ${plant.totalGrowth} growth points',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _PixelPlantPainter extends CustomPainter {
  _PixelPlantPainter({
    required this.plant,
    required this.stage,
    required this.color,
  });

  final GardenPlant plant;
  final int stage;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double pixelSize = size.width / 16;
    final Paint paint = Paint()..style = PaintingStyle.fill;

    // Simple procedural pixel art generation based on stage
    // This is a placeholder for actual pixel art assets
    // In a real app, we would load images here

    // Draw Pot
    paint.color = Colors.brown[400]!;
    _drawRect(canvas, 4, 12, 8, 4, pixelSize, paint);
    paint.color = Colors.brown[600]!;
    _drawRect(canvas, 3, 11, 10, 1, pixelSize, paint);

    // Draw Plant based on stage
    if (stage > 0) {
      paint.color = Colors.green[400]!;
      // Stem
      double stemHeight = 0;
      if (stage == 1) stemHeight = 2; // Sprout
      if (stage == 2) stemHeight = 5; // Growing
      if (stage >= 3) stemHeight = 8; // Blooming

      _drawRect(canvas, 7, 11 - stemHeight, 2, stemHeight, pixelSize, paint);

      // Leaves
      if (stage >= 2) {
        _drawRect(canvas, 5, 11 - stemHeight + 2, 2, 1, pixelSize, paint);
        _drawRect(canvas, 9, 11 - stemHeight + 1, 2, 1, pixelSize, paint);
      }

      // Flower/Fruit
      if (stage >= 3) {
        paint.color = color; // Use companion color for flower
        _drawRect(canvas, 6, 11 - stemHeight - 3, 4, 3, pixelSize, paint);
        paint.color = Colors.yellow;
        _drawRect(canvas, 7, 11 - stemHeight - 2, 2, 1, pixelSize, paint);
      }
    }
  }

  void _drawRect(
    Canvas canvas,
    double x,
    double y,
    double w,
    double h,
    double pixelSize,
    Paint paint,
  ) {
    canvas.drawRect(
      Rect.fromLTWH(x * pixelSize, y * pixelSize, w * pixelSize, h * pixelSize),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PixelPlantPainter oldDelegate) {
    return oldDelegate.stage != stage || oldDelegate.color != color;
  }
}

class _PlantSelector extends StatelessWidget {
  const _PlantSelector({
    required this.plants,
    required this.activeId,
    required this.growth,
    required this.unlockedPlants,
    required this.leaves,
    required this.onSelect,
  });

  final List<GardenPlant> plants;
  final String activeId;
  final Map<String, int> growth;
  final List<String> unlockedPlants;
  final int leaves;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Text(
              'Choose a plant to cultivate',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text('$leaves leaves total', style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: plants.map((plant) {
            final bool selected = plant.id == activeId;
            final int progress = growth[plant.id] ?? 0;
            final int target = plant.totalGrowth;
            final bool unlocked = unlockedPlants.contains(plant.id);

            return ChoiceChip(
              label: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${plant.emoji} ${plant.name}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Growth $progress/$target',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                ],
              ),
              selected: selected,
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              labelPadding: EdgeInsets.zero,
              selectedColor: theme.colorScheme.primary.withValues(alpha: 0.25),
              onSelected: unlocked ? (_) => onSelect(plant.id) : null,
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Text(
          plants
              .firstWhere((p) => p.id == activeId, orElse: () => plants.first)
              .description,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _SupportTag extends StatelessWidget {
  const _SupportTag({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final Color bgColor = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8);
    final Color borderColor = theme.dividerColor.withValues(
      alpha: isDark ? 0.16 : 0.3,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class GardenPlant {
  const GardenPlant({
    required this.id,
    required this.name,
    required this.emoji,
    required this.growthSteps,
    required this.description,
  });

  final String id;
  final String name;
  final String emoji;
  final List<int> growthSteps;
  final String description;

  int get totalGrowth => growthSteps.isEmpty ? 0 : growthSteps.last;

  int stageIndex(int progress) {
    for (int i = 0; i < growthSteps.length; i++) {
      if (progress < growthSteps[i]) {
        return i;
      }
    }
    return growthSteps.length;
  }

  String stageLabel(int stage) {
    if (stage == 0) return 'Seedling';
    if (stage == 1) return 'Sprout';
    if (stage == 2) return 'Growing';
    if (stage >= 3) return 'Blooming';
    return 'Mature';
  }

  static const List<GardenPlant> all = <GardenPlant>[
    GardenPlant(
      id: 'lavender',
      name: 'Lavender Calm',
      emoji: '💜',
      growthSteps: <int>[3, 6, 10],
      description:
          'A soothing lavender sprig that grows as you keep breathing and sharing.',
    ),
    GardenPlant(
      id: 'fern',
      name: 'Fern Resilience',
      emoji: '🌿',
      growthSteps: <int>[2, 5, 9],
      description: 'Unfurls with steady daily check-ins.',
    ),
    GardenPlant(
      id: 'sunflower',
      name: 'Sunflower Hope',
      emoji: '🌻',
      growthSteps: <int>[4, 8, 12],
      description: 'Turns toward light when you celebrate small wins.',
    ),
    GardenPlant(
      id: 'bonsai',
      name: 'Bonsai Balance',
      emoji: '🪴',
      growthSteps: <int>[5, 10, 15],
      description: 'Shaped slowly through reflection and boundaries.',
    ),
  ];
}
