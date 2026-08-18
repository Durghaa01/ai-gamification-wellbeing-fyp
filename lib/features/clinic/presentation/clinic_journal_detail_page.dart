import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../design_system/tokens/color_tokens.dart';
import '../../../design_system/tokens/typography.dart';
import '../../../features/journal/domain/journal_models.dart';
import '../../../features/journal/presentation/widgets/emoji_blob.dart';
import '../../../models/models.dart';
import '../../../services/journal_data_service.dart';

double _riskScore100(double raw) => raw <= 1 ? raw * 100 : raw;

const _moodLabels = <int, String>{
  1: 'Very happy',
  2: 'Happy',
  3: 'Neutral',
  4: 'Unhappy',
  5: 'Very unhappy',
};

int _safeMood(int? mood) => (mood ?? 3).clamp(1, 5);

const double _headerRowHeight = 180.0;

class ClinicJournalDetailPage extends ConsumerStatefulWidget {
  const ClinicJournalDetailPage({
    super.key,
    required this.patient,
    required this.onThemeChanged,
  });

  final AppUser patient;
  final ValueChanged<bool> onThemeChanged;

  @override
  ConsumerState<ClinicJournalDetailPage> createState() =>
      _ClinicJournalDetailPageState();
}

class _ClinicJournalDetailPageState
    extends ConsumerState<ClinicJournalDetailPage> {
  bool _refreshing = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final journalService = ref.watch(journalDataServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1B1F1C) : MindWellColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Journal — ${widget.patient.name}',
          style: MindWellTypography.sectionSubtitle(
            color: isDark ? Colors.white : MindWellColors.darkGray,
          ).copyWith(fontSize: 22),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _refreshing
                ? null
                : () => _refresh(journalService),
          ),
          Switch(value: isDark, onChanged: widget.onThemeChanged),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(isDark ? '☾' : '☀'),
          ),
        ],
      ),
      body: StreamBuilder<List<JournalEntry>>(
        stream: journalService.watchEntries(widget.patient.id),
        builder: (context, snapshot) {
          final entries = List<JournalEntry>.from(snapshot.data ?? const []);
          entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final latest = entries.isNotEmpty ? entries.first : null;
          final lastSeven = entries.take(7).toList();

          final positiveTags = entries
              .expand((e) => e.tags)
              .fold<Map<String, int>>({}, (map, tag) {
                final t = tag.trim().toLowerCase();
                if (t.isEmpty) return map;
                map[t] = (map[t] ?? 0) + 1;
                return map;
              });

          final tagCloud = positiveTags.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          final loading = snapshot.connectionState == ConnectionState.waiting &&
              entries.isEmpty;

          return RefreshIndicator(
            onRefresh: () => _refresh(journalService),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Colors.red.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() => _error = null),
                          ),
                        ],
                      ),
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: _headerRowHeight,
                        child: _PatientHeaderCard(
                          patient: widget.patient,
                          latest: latest,
                          isDark: isDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 200,
                      height: _headerRowHeight,
                      child: _MiniWeekChart(
                        entries: lastSeven,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                if (latest != null)
                  _InsightRow(
                    latest: latest,
                    isDark: isDark,
                  ),
                if (tagCloud.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _TagCloud(tags: tagCloud, isDark: isDark),
                ],
                const SizedBox(height: 16),
                if (loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (entries.isEmpty)
                  _EmptyJournalState(
                    patientName: widget.patient.name,
                    onRefresh: () => _refresh(journalService),
                  )
                else ...[
                  Text(
                    'Recent entries',
                    style: MindWellTypography.sectionSubtitle(
                      color: isDark ? Colors.white : MindWellColors.darkGray,
                    ).copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  ...entries.map(
                    (entry) => _EntryTile(entry: entry, isDark: isDark),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _refresh(JournalDataService service) async {
    setState(() => _refreshing = true);
    try {
      await service.fetchEntries(widget.patient.id);
      if (mounted) setState(() => _error = null);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }
}

class _PatientHeaderCard extends StatelessWidget {
  const _PatientHeaderCard({
    required this.patient,
    required this.latest,
    required this.isDark,
  });

  final AppUser patient;
  final JournalEntry? latest;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF232825) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF3F4742) : const Color(0xFFE0E3DE),
        ),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 16,
                  offset: Offset(0, 12),
                ),
              ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: MindWellColors.lightGreen.withOpacity(0.25),
            child: Text(
              patient.name.isNotEmpty ? patient.name[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.name,
                  style: MindWellTypography.cardTitle(
                    color: isDark ? Colors.white : MindWellColors.darkGray,
                  ),
                ),
                Text(
                  patient.email,
                  style: MindWellTypography.body(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(
                      label: 'Last mood',
                      value: latest == null ? '—' : 'Level ${latest!.mood}',
                      icon: Icons.mood,
                      background: isDark
                          ? MindWellColors.accentCyanSoft
                          : MindWellColors.accentBlueSoft,
                    ),
                    _Pill(
                      label: 'Risk',
                      value: latest?.risk.level ?? '—',
                      icon: Icons.warning_amber_rounded,
                      background: _riskColor(
                        latest?.risk.level,
                        isDark: isDark,
                      ).withOpacity(0.15),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.latest, required this.isDark});
  final JournalEntry latest;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _Card(
            isDark: isDark,
            child: Row(
              children: [
                EmojiBlob(mood: latest.mood, size: 58),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Latest entry',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : MindWellColors.darkGray,
                        ),
                      ),
                      Text(
                        _formatDate(latest.createdAt),
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        latest.note.isEmpty
                            ? 'No note recorded.'
                            : latest.note,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Card(
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Insights',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : MindWellColors.darkGray,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(
                      label: 'Sentiment',
                      value:
                          '${latest.sentiment.label} ${(latest.sentiment.confidence * 100).round()}%',
                      icon: Icons.insights,
                      background: isDark
                          ? MindWellColors.accentCyanSoft
                          : MindWellColors.accentBlueSoft,
                    ),
                    _Pill(
                      label: 'Risk',
                      value:
                          '${latest.risk.level} ${_riskScore100(latest.risk.score).round()}%',
                      icon: Icons.warning_amber_rounded,
                      background: _riskColor(
                        latest.risk.level,
                        isDark: isDark,
                      ).withOpacity(0.15),
                    ),
                  ],
                ),
                if (latest.risk.triggers.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Triggers',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: latest.risk.triggers
                        .map(
                          (t) => Chip(
                            label: Text(t),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniWeekChart extends StatelessWidget {
  const _MiniWeekChart({required this.entries, required this.isDark});
  final List<JournalEntry> entries;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dates = List.generate(
      7,
      (i) => DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: 6 - i)),
    );
    final map = {
      for (final e in entries)
        DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day): e,
    };

    return Container(
      width: 200,
      height: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF232825) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF3F4742) : const Color(0xFFE0E3DE),
        ),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 16,
                  offset: Offset(0, 12),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mood (7d)',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : MindWellColors.darkGray,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (_, c) {
                final barWidth = (c.maxWidth - 12) / 7;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: dates.map((d) {
                    final e = map[d];
                    final factor = e == null
                        ? 0.15
                        : (6 - e.mood).clamp(1, 5) / 5; // 1..5 mood → 1..0.2
                    final height = (c.maxHeight - 20) * factor;
                    final color = _riskColor(e?.risk.level ?? 'low',
                        isDark: isDark);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Container(
                        width: barWidth - 2,
                        height: height,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('6d ago', style: TextStyle(fontSize: 10)),
              Text('Today', style: TextStyle(fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TagCloud extends StatelessWidget {
  const _TagCloud({required this.tags, required this.isDark});
  final List<MapEntry<String, int>> tags;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return _Card(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top tags',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : MindWellColors.darkGray,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags
                .take(12)
                .map(
                  (entry) => Chip(
                    label: Text('${entry.key} (${entry.value})'),
                    backgroundColor: isDark
                        ? const Color(0xFF2D332F)
                        : MindWellColors.lightGreen.withOpacity(0.2),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.isDark});
  final JournalEntry entry;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final timestamp =
        '${entry.createdAt.year}-${entry.createdAt.month.toString().padLeft(2, '0')}-${entry.createdAt.day.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF232825) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF3F4742) : const Color(0xFFE0E3DE),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EmojiBlob(mood: entry.mood, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _moodLabels[entry.mood] ?? 'Mood',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? Colors.white
                            : MindWellColors.darkGray,
                      ),
                    ),
                    _RiskBadge(level: entry.risk.level, isDark: isDark),
                  ],
                ),
                const SizedBox(height: 6),
                if (entry.tags.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: entry.tags
                        .map(
                          (tag) => Chip(
                            label: Text(tag),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                if (entry.tags.isNotEmpty) const SizedBox(height: 8),
                Text(
                  entry.note.isEmpty ? 'No note.' : entry.note,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            timestamp,
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _RiskBadge extends StatelessWidget {
  const _RiskBadge({required this.level, required this.isDark});
  final String level;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final color = _riskColor(level, isDark: isDark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(
        level.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : MindWellColors.darkGray,
        ),
      ),
    );
  }
}

class _EmptyJournalState extends StatelessWidget {
  const _EmptyJournalState({
    required this.patientName,
    required this.onRefresh,
  });

  final String patientName;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.pending_actions_outlined, size: 56),
          const SizedBox(height: 8),
          Text(
            '$patientName has no journal entries yet.',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, required this.isDark});
  final Widget child;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF232825) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF3F4742) : const Color(0xFFE0E3DE),
        ),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 16,
                  offset: Offset(0, 10),
                ),
              ],
      ),
      child: child,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.value,
    required this.icon,
    required this.background,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Color _riskColor(String? level, {required bool isDark}) {
  switch (level) {
    case 'high':
      return Colors.redAccent;
    case 'moderate':
      return Colors.orangeAccent;
    case 'low':
      return isDark ? MindWellColors.accentCyan : MindWellColors.accentBlue;
    default:
      return isDark ? Colors.white70 : Colors.grey.shade700;
  }
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
