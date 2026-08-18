/// Defines the list of experiments that can be evaluated in the app.
enum ExperimentKey {
  landingHero,
  companionsGuestExperience,
  companionsRegisteredExperience,
}

class ExperimentVariant {
  const ExperimentVariant({
    required this.id,
    required this.weight,
    this.description,
  }) : assert(weight >= 0, 'Variant weight must be non-negative');

  final String id;
  final double weight;
  final String? description;
}

class ExperimentDefinition {
  const ExperimentDefinition({
    required this.key,
    required this.variants,
    this.defaultVariant = 'control',
  }) : assert(
         variants.length >= 1,
         'At least one variant is required for an experiment.',
       );

  final ExperimentKey key;
  final List<ExperimentVariant> variants;
  final String defaultVariant;

  ExperimentVariant get defaultVariantConfig {
    return variants.firstWhere(
      (variant) => variant.id == defaultVariant,
      orElse: () => variants.first,
    );
  }

  double get totalWeight {
    return variants.fold<double>(0, (value, variant) => value + variant.weight);
  }
}

class ExperimentConfig {
  factory ExperimentConfig.standard() {
    return ExperimentConfig._(
      definitions: {
        ExperimentKey.landingHero: ExperimentDefinition(
          key: ExperimentKey.landingHero,
          defaultVariant: 'control',
          variants: const [
            ExperimentVariant(id: 'control', weight: 1),
            ExperimentVariant(
              id: 'immersive',
              weight: 1,
              description: 'Elevated hero layout emphasising telehealth CTA.',
            ),
          ],
        ),
        ExperimentKey.companionsGuestExperience: ExperimentDefinition(
          key: ExperimentKey.companionsGuestExperience,
          defaultVariant: 'control',
          variants: const [
            ExperimentVariant(id: 'control', weight: 1),
            ExperimentVariant(
              id: 'guided',
              weight: 1,
              description:
                  'Guest flow with scripted intro sequence before chat.',
            ),
          ],
        ),
        ExperimentKey.companionsRegisteredExperience: ExperimentDefinition(
          key: ExperimentKey.companionsRegisteredExperience,
          defaultVariant: 'control',
          variants: const [
            ExperimentVariant(id: 'control', weight: 1),
            ExperimentVariant(
              id: 'persona-fastlane',
              weight: 1,
              description: 'Skips persona selection for returning users.',
            ),
          ],
        ),
      },
      forcedAssignments: _parseOverrides(
        const String.fromEnvironment('EXPERIMENT_OVERRIDES', defaultValue: ''),
      ),
    );
  }

  const ExperimentConfig._({
    required this.definitions,
    required this.forcedAssignments,
  });

  final Map<ExperimentKey, ExperimentDefinition> definitions;
  final Map<ExperimentKey, String> forcedAssignments;

  ExperimentDefinition definitionOf(ExperimentKey key) {
    final definition = definitions[key];
    if (definition == null) {
      throw ArgumentError.value(key, 'key', 'Experiment not defined');
    }
    return definition;
  }

  static Map<ExperimentKey, String> _parseOverrides(String raw) {
    if (raw.trim().isEmpty) return const {};
    final overrides = <ExperimentKey, String>{};
    for (final entry in raw.split(',')) {
      final parts = entry.split('=');
      if (parts.length != 2) continue;
      final keyName = parts.first.trim();
      final variant = parts.last.trim();
      if (keyName.isEmpty || variant.isEmpty) continue;
      final key = ExperimentKey.values.firstWhere(
        (candidate) => candidate.name == keyName,
        orElse: () => ExperimentKey.landingHero,
      );
      overrides[key] = variant;
    }
    return overrides;
  }
}

class ExperimentService {
  ExperimentService({ExperimentConfig? config})
    : _config = config ?? ExperimentConfig.standard();

  final ExperimentConfig _config;
  final Map<String, Map<ExperimentKey, String>> _cache = {};

  String variantFor(ExperimentKey key, {required String subjectId}) {
    final cacheHit = _cache[subjectId]?[key];
    if (cacheHit != null) return cacheHit;

    final forced = _config.forcedAssignments[key];
    if (forced != null) {
      _remember(subjectId, key, forced);
      return forced;
    }

    final definition = _config.definitionOf(key);
    final slot = _deterministicSlot(subjectId, key);
    final variant = _pickVariant(definition, slot);
    _remember(subjectId, key, variant.id);
    return variant.id;
  }

  void _remember(String subjectId, ExperimentKey key, String variantId) {
    _cache.putIfAbsent(subjectId, () => {})[key] = variantId;
  }

  ExperimentVariant _pickVariant(ExperimentDefinition definition, double slot) {
    final total = definition.totalWeight;
    if (total <= 0) return definition.defaultVariantConfig;

    double cumulative = 0;
    for (final candidate in definition.variants) {
      cumulative += candidate.weight / total;
      if (slot <= cumulative) {
        return candidate;
      }
    }
    return definition.variants.last;
  }

  double _deterministicSlot(String subjectId, ExperimentKey key) {
    final seed = '${key.name}|$subjectId';
    final hash = _stableHash(seed);
    return (hash % 1000000) / 1000000.0;
  }

  int _stableHash(String value) {
    const int fnvPrime = 16777619;
    const int fnvOffset = 2166136261;
    int hash = fnvOffset;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }
}

class ExperimentResolver {
  ExperimentResolver({
    required ExperimentService service,
    required String visitorId,
  }) : _service = service,
       _visitorId = visitorId;

  final ExperimentService _service;
  final String _visitorId;

  String variantFor(ExperimentKey key, {String? userId}) {
    final subject = _buildSubjectId(userId);
    return _service.variantFor(key, subjectId: subject);
  }

  String _buildSubjectId(String? userId) {
    final normalisedUserId = userId?.trim().toLowerCase();
    if (normalisedUserId != null && normalisedUserId.isNotEmpty) {
      return 'user:$normalisedUserId';
    }
    return 'visitor:$_visitorId';
  }
}

class ExperimentAssignments {
  ExperimentAssignments({
    required this.variantByKey,
    required this.generatedAt,
  });

  final Map<ExperimentKey, String> variantByKey;
  final DateTime generatedAt;

  String variantFor(ExperimentKey key) {
    return variantByKey[key] ?? 'control';
  }
}
