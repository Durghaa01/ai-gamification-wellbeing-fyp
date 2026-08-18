import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

import '../../../design_system/tokens/color_tokens.dart';
import '../../../design_system/tokens/typography.dart';
import '../../../services/api/journal_remote_api.dart';
import '../../../services/api/mindwell_api_client.dart';
import '../domain/journal_models.dart';
import 'widgets/emoji_blob.dart';

const _moodLabels = <int, String>{
  1: 'Very happy',
  2: 'Happy',
  3: 'Neutral',
  4: 'Unhappy',
  5: 'Very unhappy',
};

double _riskScore100(double raw) => raw <= 1 ? raw * 100 : raw;

Color _moodTint(int mood) {
  switch (mood) {
    case 1:
      return const Color(0xFF06B6D4);
    case 2:
      return const Color(0xFF22C55E);
    case 3:
      return const Color(0xFFFACC15);
    case 4:
      return const Color(0xFFF97316);
    case 5:
    default:
      return const Color(0xFFEF4444);
  }
}

/// 与 EmojiBlob 一致的 5 组圆形渐变（用于日历描边外圈）
RadialGradient _emojiCircleGradient(int mood) {
  switch (mood) {
    case 1: // Very happy — 薄荷绿
      return const RadialGradient(
        center: Alignment(-0.2, -0.2),
        radius: 1.05,
        colors: [
          Color(0xFFBFEFD8),
          Color(0xFFA2E8C6),
          Color(0xFF6DD3A3),
          Color(0xFFAEEFD0),
        ],
        stops: [0.0, 0.35, 0.7, 1.0],
      );
    case 2: // Happy — 浅青绿/浅绿
      return const RadialGradient(
        center: Alignment(0.15, -0.15),
        radius: 1.05,
        colors: [
          Color(0xFFE3F7DB),
          Color(0xFFCFF0BD),
          Color(0xFF8AD98F),
          Color(0xFFE9F9E4),
        ],
        stops: [0.0, 0.4, 0.72, 1.0],
      );
    case 3: // Neutral — 淡紫粉
      return const RadialGradient(
        center: Alignment(-0.05, -0.1),
        radius: 1.1,
        colors: [
          Color(0xFFEADCF8),
          Color(0xFFF6D6E4),
          Color(0xFFE2C7F2),
          Color(0xFFF4D2DE),
        ],
        stops: [0.0, 0.38, 0.68, 1.0],
      );
    case 4: // Unhappy — 桃杏橙
      return const RadialGradient(
        center: Alignment(0.15, -0.25),
        radius: 1.05,
        colors: [
          Color(0xFFFDE5CC),
          Color(0xFFF9D2A8),
          Color(0xFFF2B77A),
          Color(0xFFFBE1C6),
        ],
        stops: [0.0, 0.42, 0.72, 1.0],
      );
    default: // 5 Very unhappy — 玫瑰红
      return const RadialGradient(
        center: Alignment(-0.1, -0.2),
        radius: 1.05,
        colors: [
          Color(0xFFF8D1D1),
          Color(0xFFF3B3B3),
          Color(0xFFE57474),
          Color(0xFFF2C0C8),
        ],
        stops: [0.0, 0.4, 0.72, 1.0],
      );
  }
}

/// “七天情绪条”线性渐变（与 Emoji 颜色一致）
LinearGradient _emojiBarGradient(int mood) {
  switch (mood) {
    case 1:
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFBFEFD8), Color(0xFFA2E8C6), Color(0xFF6DD3A3)],
        stops: [0.0, 0.55, 1.0],
      );
    case 2:
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFE3F7DB), Color(0xFFCFF0BD), Color(0xFF8AD98F)],
        stops: [0.0, 0.56, 1.0],
      );
    case 3:
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFEADCF8), Color(0xFFF6D6E4), Color(0xFFE2C7F2)],
        stops: [0.0, 0.55, 1.0],
      );
    case 4:
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFDE5CC), Color(0xFFF9D2A8), Color(0xFFF2B77A)],
        stops: [0.0, 0.56, 1.0],
      );
    default:
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF8D1D1), Color(0xFFF3B3B3), Color(0xFFE57474)],
        stops: [0.0, 0.56, 1.0],
      );
  }
}

class JournalStatsPage extends StatefulWidget {
  const JournalStatsPage({
    super.key,
    required this.repository,
    required this.onThemeChanged,
    required this.onOpenJournal,
  });

  final JournalRepository repository;
  final ValueChanged<bool> onThemeChanged;
  final Future<void> Function(BuildContext context) onOpenJournal;

  @override
  State<JournalStatsPage> createState() => _JournalStatsPageState();
}

class _JournalStatsPageState extends State<JournalStatsPage> {
  JournalEntry? _selectedEntry;
  late int _calendarYear;
  late int _calendarMonth;
  bool _loading = true;
  bool _savingTriggers = false;
  final bool _useRemoteBackend =
      const bool.fromEnvironment('USE_REMOTE_BACKEND', defaultValue: true);
  JournalRemoteApi? _remoteApi;

  static const double _chartsSectionHeight = 240;

  @override
  void initState() {
    super.initState();
    _setupRemote();
    _resetSelectionFromCurrent();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = DateTime.now();
    final entriesNow = widget.repository.entries;
    final todayEntry = _entryOn(entriesNow, today);
    final lastSeven = _lastSeven(entriesNow);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Journal Dashboard',
          style: MindWellTypography.sectionSubtitle(
            color: isDark ? Colors.white : MindWellColors.darkGray,
          ).copyWith(fontSize: 24),
        ),
        actions: [
          Switch(value: isDark, onChanged: widget.onThemeChanged),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(isDark ? '☾' : '☀'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => _openJournal(context),
                icon: const Icon(Icons.edit_note_outlined),
                label: const Text('Open daily journal'),
              ),
            ),
            if (_loading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(minHeight: 2),
            ],
            const SizedBox(height: 16),

            const SizedBox(height: 28),

            // Today card
            _Card(
              isDark: isDark,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EmojiBlob(mood: todayEntry?.mood ?? 3, size: 64),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Today',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : MindWellColors.darkGray,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (todayEntry != null) ...[
                          Builder(
                            builder: (_) {
                              final riskScore =
                                  _riskScore100(todayEntry.risk.score);
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _moodLabel(todayEntry.mood),
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : MindWellColors.darkGray,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Sentiment: ${todayEntry.sentiment.label} '
                                    '(${(todayEntry.sentiment.confidence * 100).round()}%)',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: riskScore / 100,
                                    minHeight: 8,
                                    backgroundColor: isDark
                                        ? const Color(0xFF2D332F)
                                        : const Color(0xFFE5E8E2),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _riskColor(todayEntry.risk.level),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Risk ${todayEntry.risk.level} '
                                    '(${riskScore.toStringAsFixed(0)}/100)',
                                    style: TextStyle(
                                      color:
                                          isDark ? Colors.white70 : Colors.black54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ] else ...[
                          Text(
                            'No entry for today yet.',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: () => _openJournal(context),
                            icon: const Icon(Icons.edit),
                            label: const Text('Write today’s journal'),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tip: a quick 1–2 minute note is enough. Your dashboard trends update right away.',
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black45,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Charts row
            SizedBox(
              height: _chartsSectionHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _Card(
                      isDark: isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mood — last 7 days',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : MindWellColors.darkGray,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _SevenDayChart(
                              entries: lastSeven,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                  child: _Card(
                    isDark: isDark,
                    child: _TriggersPanel(
                      entries: lastSeven,
                      isDark: isDark,
                      onAnalysis: () => _openTriggerInsightsDialog(
                        context,
                        _computeTagStats(widget.repository.entries),
                        isDark,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            ),
            const SizedBox(height: 18),

            // Calendar + detail
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Card(
                    isDark: isDark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CalendarHeader(
                          year: _calendarYear,
                          month: _calendarMonth,
                          onPrevious: () => setState(_previousMonth),
                          onNext: () => setState(_nextMonth),
                        ),
                        const SizedBox(height: 12),
                        _MonthGrid(
                          year: _calendarYear,
                          month: _calendarMonth,
                          repository: widget.repository,
                          onSelect: (e) => setState(() => _selectedEntry = e),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _Card(
                    isDark: isDark,
                    child: _RecordDetail(
                      entry: _selectedEntry,
                      isDark: isDark,
                      title: 'Selected record',
                      onEditTriggers: (list) => _saveSelectedTriggers(
                        context,
                        list,
                      ),
                      isEditing: _savingTriggers,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // -------- Helpers (data) --------

  List<JournalEntry> _lastSeven(List<JournalEntry> entries) {
    final today = DateTime.now();
    final normalized = DateTime(today.year, today.month, today.day);
    final start = normalized.subtract(const Duration(days: 6));
    return entries.where((e) {
      final d = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
      return (d.isAtSameMomentAs(start) || d.isAfter(start)) &&
          d.isBefore(normalized.add(const Duration(days: 1)));
    }).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  JournalEntry? _entryOn(List<JournalEntry> entries, DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    return entries.firstWhereOrNull((e) {
      final d = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
      return d.isAtSameMomentAs(target);
    });
  }

  Future<void> _editLatestTriggers(BuildContext context) async {
    final latest = widget.repository.entries.isNotEmpty
        ? widget.repository.entries.last
        : null;
    if (latest == null) return;

    final controller = TextEditingController();
    final initial = latest.triggers.toSet();
    final updated = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        Set<String> working = {...initial};
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              void addTrigger(String value) {
                final t = value.trim().toLowerCase();
                if (t.isEmpty) return;
                setSheetState(() => working.add(t));
                controller.clear();
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Edit triggers (latest entry)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (working.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No triggers yet. Add one below.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: working
                          .map(
                            (t) => InputChip(
                              label: Text(t),
                              onDeleted: () => setSheetState(
                                () => working.remove(t),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    textInputAction: TextInputAction.done,
                    onSubmitted: addTrigger,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.add),
                      hintText: 'Add trigger (e.g., exam, sleep, family)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => Navigator.pop(
                          context,
                          working.toList(growable: false),
                        ),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    controller.dispose();
    if (updated == null) return;

    final normalized = updated
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();

    final saved = latest.copyWith(
      risk: latest.risk.copyWith(triggers: normalized),
      triggers: normalized,
    );
    widget.repository.save(saved);
    setState(() {
      if (_selectedEntry != null &&
          _selectedEntry!.createdAt == latest.createdAt) {
        _selectedEntry = saved;
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Triggers updated for latest entry')),
      );
    }
  }

  // Tag stats for Insights dialog (last 30d) —— 以“文本抽取的事件 triggers”为主
  List<_TagStat> _computeTagStats(List<JournalEntry> entries) {
    final now = DateTime.now();
    final from = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 30));
    final map = <String, _TagStat>{};

    for (final e in entries) {
      final d = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
      if (d.isBefore(from)) continue;

      // 只统计“事件 triggers”，不再 fallback 到情绪类 risk.triggers
      final triggers = e.triggers;
      if (triggers.isEmpty) continue;

      for (final t in triggers) {
        map[t] ??= _TagStat(tag: t);
        final s = map[t]!;
        s.count += 1;
        s.sumMood += e.mood.toDouble();
        s.sumRisk += _riskScore100(e.risk.score);
        final pol = e.sentiment.label.toLowerCase();
        if (pol.contains('positive')) s.pos += 1;
        if (pol.contains('negative')) s.neg += 1;
        if (pol.contains('neutral')) s.neu += 1;
      }
    }

    final stats = map.values.toList();
    stats.sort((a, b) => b.count.compareTo(a.count));
    return stats;
  }

  // -------- Navigation / scenario --------

  Future<void> _openJournal(BuildContext context) async {
    await widget.onOpenJournal(context);
    if (!mounted) return;
    await _refreshFromRemote();
    _resetSelectionFromCurrent();
    setState(() {});
  }

  Future<void> _saveSelectedTriggers(
    BuildContext context,
    List<String> triggers,
  ) async {
    final selected = _selectedEntry;
    if (selected == null) return;

    final normalized = triggers
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .toList();

    setState(() => _savingTriggers = true);
    try {
      JournalEntry updated;
      if (_remoteApi != null) {
        try {
          updated = await _remoteApi!.upsertEntry(
            userId: 'user_primary',
            mood: selected.mood,
            tags: selected.tags,
            note: selected.note,
            entryDate: selected.createdAt,
            manualTriggers: normalized,
          );
        } catch (e) {
          // fall back to local update if remote fails
          updated = selected.copyWith(
            risk: selected.risk.copyWith(triggers: normalized),
            triggers: normalized,
          );
        }
      } else {
        updated = selected.copyWith(
          risk: selected.risk.copyWith(triggers: normalized),
          triggers: normalized,
        );
      }

      widget.repository.save(updated);
      _selectedEntry = updated;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Triggers updated')),
      );
    } finally {
      if (mounted) setState(() => _savingTriggers = false);
    }
  }

  void _resetSelectionFromCurrent() {
    final entries = widget.repository.entries;
    _selectedEntry = entries.isNotEmpty ? entries.last : null;
    final ref = _selectedEntry?.createdAt ?? DateTime.now();
    _calendarYear = ref.year;
    _calendarMonth = ref.month;
  }

  /* ------------------------ Remote bootstrap ------------------------ */

  String _resolveBaseUrl() {
    const api = String.fromEnvironment('API_BASE');
    const alt = String.fromEnvironment('JOURNAL_API_BASE');
    if (api.isNotEmpty) return api;
    if (alt.isNotEmpty) return alt;
    return 'http://127.0.0.1:8000';
  }

  Future<void> _setupRemote() async {
    if (!_useRemoteBackend) {
      setState(() => _loading = false);
      return;
    }
    try {
      final client = MindWellApiClient(baseUrl: _resolveBaseUrl());
      _remoteApi = JournalRemoteApi(client: client);
      await _refreshFromRemote();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshFromRemote() async {
    if (_remoteApi == null) return;
    try {
      final entries = await _remoteApi!.fetchEntries('user_primary', limit: 30);
      widget.repository.replaceAll(entries);
      if (mounted) {
        _resetSelectionFromCurrent();
        setState(() {});
      }
    } catch (_) {
      // ignore remote errors; keep existing entries
    }
  }

  void _previousMonth() {
    if (_calendarMonth == 1) {
      _calendarMonth = 12;
      _calendarYear -= 1;
    } else {
      _calendarMonth -= 1;
    }
  }

  void _nextMonth() {
    if (_calendarMonth == 12) {
      _calendarMonth = 1;
      _calendarYear += 1;
    } else {
      _calendarMonth += 1;
    }
  }

  // -------- Trigger mood stats --------

  List<_TriggerMoodStat> _computeTriggerMoodStats(
    List<JournalEntry> entries,
  ) {
    final map = <String, _TriggerMoodStat>{};
    for (final e in entries) {
      final triggers = e.triggers;
      for (final t in triggers) {
        final stat = map.putIfAbsent(t, () => _TriggerMoodStat(tag: t));
        stat.count += 1;
        stat.sumMood += e.mood;
        stat.sumRisk += _riskScore100(e.risk.score);
      }
    }
    final list = map.values.toList();
    list.sort((a, b) => b.count.compareTo(a.count));
    return list;
  }

  String _summarizeTriggerMood(List<_TriggerMoodStat> stats) {
    if (stats.isEmpty) return '';
    final top = stats.take(3).toList();
    final best = top.reduce((a, b) => a.avgMood < b.avgMood ? a : b);
    final worst = top.reduce((a, b) => a.avgMood > b.avgMood ? a : b);
    return [
      'Last 30 days:',
      'Most common: ${top.first.tag} (${top.first.count}×, mood ${_moodLabelFromScore(top.first.avgMood)}).',
      if (best.tag != top.first.tag)
        'Best mood: ${best.tag} (${_moodLabelFromScore(best.avgMood)}).',
      'Toughest: ${worst.tag} (${_moodLabelFromScore(worst.avgMood)}).',
    ].join(' ');
  }

  String _moodLabelFromScore(double mood) {
    final rounded = mood.toStringAsFixed(1);
    if (mood <= 1.5) return '$rounded / very positive';
    if (mood <= 2.5) return '$rounded / positive';
    if (mood <= 3.5) return '$rounded / neutral';
    if (mood <= 4.5) return '$rounded / negative';
    return '$rounded / very negative';
  }

  // -------- Insights dialog --------

  void _openTriggerInsightsDialog(
    BuildContext context,
    List<_TagStat> stats,
    bool isDark,
  ) {
    final moodStats = _computeTriggerMoodStats(widget.repository.entries);
    final summary = _summarizeTriggerMood(moodStats);
    showDialog(
      context: context,
      builder: (ctx) {
        final top = stats.take(10).toList();
        final maxCount = top.isEmpty
            ? 1
            : top.map((e) => e.count).reduce((a, b) => a > b ? a : b);

        return AlertDialog(
          title: const Text('Trigger Insights (last 30 days)'),
          content: SizedBox(
            width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (summary.isNotEmpty) ...[
                  const Text(
                    'Quick summary',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(summary),
                  const SizedBox(height: 16),
                ],
                  const Text(
                    'Frequency',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    children: top.map((s) {
                      final ratio = s.count / maxCount;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 120,
                              child: Text(
                                s.tag,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                height: 10,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? MindWellColors.accentCyanSoft
                                      : MindWellColors.accentBlueSoft,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: ratio.clamp(0, 1),
                                  child: Container(
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? MindWellColors.accentCyan
                                          : MindWellColors.accentBlue,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${s.count}×'),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Correlations',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ...top.map((s) {
                    final total = (s.pos + s.neg + s.neu).clamp(1, 999999);
                    final posPct = (s.pos * 100 / total).round();
                    final negPct = (s.neg * 100 / total).round();
                    final avgMood = (s.sumMood / s.count).toStringAsFixed(1);
                    final avgRisk = (s.sumRisk / s.count).toStringAsFixed(0);
                    final tendency = negPct >= 50
                        ? 'often paired with negative mood'
                        : (posPct >= 50
                              ? 'often paired with positive mood'
                              : 'mixed mood');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            height: 1.35,
                          ),
                          children: [
                            TextSpan(
                              text: '${s.tag}: ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(
                              text:
                                  '$tendency (positive $posPct%, negative $negPct%). ',
                            ),
                            TextSpan(
                              text: 'Avg mood $avgMood, avg risk $avgRisk/100.',
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  const Text(
                    'AI summary',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _heuristicSummary(top),
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

// ---------- Sub Components ----------

class _Card extends StatelessWidget {
  const _Card({required this.isDark, required this.child});
  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
                  color: Color(0x11000000),
                  blurRadius: 16,
                  offset: Offset(0, 10),
                ),
              ],
      ),
      child: child,
    );
  }
}

class _SevenDayChart extends StatelessWidget {
  const _SevenDayChart({required this.entries, required this.isDark});
  final List<JournalEntry> entries;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final normalized = DateTime(today.year, today.month, today.day);
    final dates = List.generate(
      7,
      (i) => normalized.subtract(Duration(days: 6 - i)),
    );

    return LayoutBuilder(
      builder: (_, constraints) {
        final barMaxHeight = (constraints.maxHeight - 40).clamp(
          0,
          double.infinity,
        );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: dates.map((d) {
            final e = entries.firstWhereOrNull((x) => x.occursOn(d));
            final double h = e == null
                ? 0.0
                : (e.moodPercent / 100) * (barMaxHeight);
            return Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 24,
                    height: h,
                    decoration: e == null
                        ? BoxDecoration(
                            color: isDark
                                ? const Color(0xFF2D332F)
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(8),
                          )
                        : BoxDecoration(
                            gradient: _emojiBarGradient(e.mood),
                            borderRadius: BorderRadius.circular(8),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _weekdayShort(d.weekday),
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _TriggersPanel extends StatelessWidget {
  const _TriggersPanel({
    required this.entries,
    required this.isDark,
    required this.onAnalysis,
  });

  final List<JournalEntry> entries;
  final bool isDark;
  final VoidCallback onAnalysis;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final e in entries) {
      final triggers =
          e.triggers.where((t) => t.trim().toLowerCase() != 'unknown');
      for (final t in triggers) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // header + analysis
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Triggers spotted',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : MindWellColors.darkGray,
              ),
            ),
            TextButton.icon(
              onPressed: onAnalysis,
              icon: const Icon(Icons.analytics_outlined, size: 18),
              label: const Text('Analysis'),
              style: TextButton.styleFrom(
                foregroundColor: isDark
                    ? MindWellColors.accentCyan
                    : MindWellColors.accentBlue,
              ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: sorted.isEmpty
              ? Text(
                  'No recurring triggers detected this week.',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final e = sorted[i];
                    return Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2D332F)
                            : const Color(0xFFF1F4F0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            e.key,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            '${e.value}×',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.year,
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });
  final int year;
  final int month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrevious),
        Text(
          '${_months[month - 1]} $year',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.year,
    required this.month,
    required this.repository,
    required this.onSelect,
  });

  final int year;
  final int month;
  final JournalRepository repository;
  final ValueChanged<JournalEntry> onSelect;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(year, month, 1);
    final last = DateTime(year, month + 1, 0);
    final leading = first.weekday % 7;

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final cell = (constraints.maxWidth - spacing * 6) / 7; // 正方形单元格边长
        final circle = cell - 10; // 圆圈直径（给点内边距看起来更透气）

        final weeks = ((leading + last.day) / 7).ceil();
        final height = weeks * cell + (weeks - 1) * spacing;

        return SizedBox(
          height: height,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              childAspectRatio: 1, // 每个格子正方形
            ),
            itemCount: leading + last.day,
            itemBuilder: (_, i) {
              // 前导空白
              if (i < leading) return const SizedBox.shrink();

              final day = i - leading + 1;
              final date = DateTime(year, month, day);
              final entry = repository.entryOn(date);

              return GestureDetector(
                onTap: entry != null ? () => onSelect(entry) : null,
                child: Center(
                  child: _CalendarDay(
                    day: day,
                    entry: entry,
                    size: circle, // ✅ 必填：统一尺寸
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.day,
    required this.entry,
    required this.size,
  });

  final int day;
  final JournalEntry? entry;
  final double size;

  @override
  Widget build(BuildContext context) {
    final mood = entry?.mood;
    final has = mood != null;

    final double outer = size; // 外圈直径
    final double gap = (size * 0.22).clamp(4.0, 10.0); // 圆环厚度
    final double inner = outer - gap; // 内圈直径

    if (!has) {
      // 无记录：浅灰描边 + 白色内圈，占位与有记录一致
      return Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: outer,
            height: outer,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              border: Border.all(color: const Color(0xFFE0E3DE), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
          ),
          Container(
            width: inner,
            height: inner,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
          Text(
            '$day',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black.withOpacity(0.7),
            ),
          ),
        ],
      );
    }

    // 有记录：与 Emoji 一致的渐变描边
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: outer,
          height: outer,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: _emojiCircleGradient(mood!), // 与 Emoji 同配色
            boxShadow: const [
              BoxShadow(
                color: Color(0x15000000),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
        ),
        Container(
          width: inner,
          height: inner,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
        ),
        Text(
          '$day',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.black.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}

class _RecordDetail extends StatelessWidget {
  const _RecordDetail({
    required this.entry,
    required this.isDark,
    required this.title,
    required this.onEditTriggers,
    this.isEditing = false,
  });
  final JournalEntry? entry;
  final bool isDark;
  final String title;
  final ValueChanged<List<String>> onEditTriggers;
  final bool isEditing;

  void _showEditTriggers(BuildContext context) async {
    if (entry == null) return;
    final controller = TextEditingController();
    final initial = entry!.triggers.toSet();

    final updated = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        Set<String> working = {...initial};
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              void addTrigger(String value) {
                final t = value.trim().toLowerCase();
                if (t.isEmpty) return;
                setSheetState(() => working.add(t));
                controller.clear();
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Edit triggers',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (working.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No triggers yet. Add one below.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: working
                          .map(
                            (t) => InputChip(
                              label: Text(t),
                              onDeleted: () => setSheetState(
                                () => working.remove(t),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    textInputAction: TextInputAction.done,
                    onSubmitted: addTrigger,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.add),
                      hintText: 'Add trigger (e.g., exam, sleep, family)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => Navigator.pop(
                          context,
                          working.toList(growable: false),
                        ),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    controller.dispose();
    if (updated == null) return;
    onEditTriggers(
      updated
          .map((t) => t.trim().toLowerCase())
          .where((t) => t.isNotEmpty)
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (entry == null) {
      return Text(
        'Select a highlighted date to review your reflections.',
        style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
      );
    }

    final date = entry!.createdAt;
    final dateStr = '${_monthShort(date.month)} ${date.day}, ${date.year}';

    final triggers = entry!.triggers;
    final tags = entry!.tags;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // title + date
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : MindWellColors.darkGray,
              ),
            ),
            Text(
              dateStr,
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            EmojiBlob(mood: entry!.mood, size: 52),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _moodLabel(entry!.mood),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : MindWellColors.darkGray,
                  ),
                ),
                Text(
                  '${entry!.sentiment.label} '
                  '(${(entry!.sentiment.confidence * 100).round()}%)',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Triggers detected',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : MindWellColors.darkGray,
              ),
            ),
            TextButton.icon(
              onPressed: entry == null || isEditing
                  ? null
                  : () => _showEditTriggers(context),
              icon: isEditing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.edit_outlined, size: 18),
              label: Text(isEditing ? 'Saving...' : 'Edit'),
              style: TextButton.styleFrom(
                foregroundColor: isDark
                    ? MindWellColors.accentCyan
                    : MindWellColors.accentBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: triggers.isEmpty
              ? [
                  Text(
                    'No triggers',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ]
              : triggers.map((t) => Chip(label: Text(t))).toList(),
        ),

        const SizedBox(height: 12),
        Text(
          'User tags',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : MindWellColors.darkGray,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags.isEmpty
              ? [
                  Text(
                    'No tags',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ]
              : tags.map((t) => Chip(label: Text(t))).toList(),
        ),

        const SizedBox(height: 12),
        Text(
          'Reflection',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : MindWellColors.darkGray,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          entry!.note.isEmpty ? 'No note recorded.' : entry!.note,
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
      ],
    );
  }
}

// ---------- Helpers ----------

String _moodLabel(int m) => _moodLabels[m] ?? 'Mood';

Color _riskColor(String? level) {
  switch (level) {
    case 'high':
      return const Color(0xFFE57373);
    case 'moderate':
      return const Color(0xFFF6C76B);
    default:
      return MindWellColors.lightGreen;
  }
}

String _weekdayShort(int weekday) =>
    ['S', 'M', 'T', 'W', 'T', 'F', 'S'][weekday % 7];

String _monthShort(int m) => [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][m - 1];

// ---------- Tag stats model & summary ----------

class _TagStat {
  _TagStat({required this.tag});
  final String tag;
  int count = 0;
  int pos = 0;
  int neg = 0;
  int neu = 0;
  double sumMood = 0;
  double sumRisk = 0;
}

class _TriggerMoodStat {
  _TriggerMoodStat({required this.tag});

  final String tag;
  int count = 0;
  double sumMood = 0;
  double sumRisk = 0;

  double get avgMood => count == 0 ? 0 : sumMood / count;
  double get avgRisk => count == 0 ? 0 : sumRisk / count;
}

String _heuristicSummary(List<_TagStat> stats) {
  if (stats.isEmpty) {
    return 'No triggers with enough data yet. Log a few journals this week to unlock insights.';
  }
  final top = stats.first;
  final totalPN = (top.pos + top.neg + top.neu).clamp(1, 999999);
  final negPct = (top.neg * 100 / totalPN).round();
  final posPct = (top.pos * 100 / totalPN).round();
  final mood = (top.sumMood / top.count);
  final risk = (top.sumRisk / top.count);

  final buf = StringBuffer();
  buf.writeln(
    'Top driver this month is **${top.tag}** (${top.count} mentions).',
  );
  if (negPct >= 55) {
    buf.writeln(
      'It is frequently linked with negative mood ($negPct%). Consider lighter workload and better sleep on days marked with this trigger.',
    );
  } else if (posPct >= 55) {
    buf.writeln(
      'It usually correlates with positive mood ($posPct%). Great to keep!',
    );
  } else {
    buf.writeln('Effect on mood is mixed across contexts.');
  }
  buf.writeln(
    'Average mood around this trigger is ${mood.toStringAsFixed(1)} (1=very happy, 5=very unhappy), with average risk ${risk.toStringAsFixed(0)}/100.',
  );
  return buf.toString();
}
