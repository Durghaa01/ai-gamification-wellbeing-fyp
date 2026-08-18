import 'package:flutter/material.dart';

import '../../../design_system/tokens/color_tokens.dart';
import '../../../design_system/tokens/typography.dart';
import '../../../services/api/journal_remote_api.dart';
import '../../../services/api/mindwell_api_client.dart';
import '../application/journal_service.dart';
import '../domain/journal_models.dart';
import 'journal_stats_page.dart';
import 'widgets/emoji_blob.dart';

const _moodLabels = <int, String>{
  1: 'Very happy',
  2: 'Happy',
  3: 'Neutral',
  4: 'Unhappy',
  5: 'Very unhappy',
};

const List<String> _builtInTags = <String>[
  'joy',
  'excitement',
  'calm',
  'safety',
  'content',
  'sadness',
  'anxiety',
  'anger',
  'fatigue',
  'stress',
  'disappointment',
];

String _canonicalizeTag(String tag) => tag.trim().toLowerCase();

String _displayTag(String tag) {
  if (tag.isEmpty) return tag;
  return tag
      .split(RegExp(r'\s+'))
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

double _riskScore100(double raw) => raw <= 1 ? raw * 100 : raw;

String _dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

const _sectionTitleStyle = TextStyle(fontSize: 20, fontWeight: FontWeight.w700);

class JournalPage extends StatefulWidget {
  const JournalPage({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.storeKey,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final String storeKey;

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  late bool _isDark;
  final _noteController = TextEditingController();

  // ✅ 可变列表 + 选中集合；支持自定义 tag
  final List<String> _availableTags = List<String>.from(_builtInTags);
  final Set<String> _selectedTags = <String>{};
  static const int _maxTags = 3;

  int _mood = 3;
  bool _saving = false;
  bool _loading = true;
  final bool _useRemoteBackend =
      const bool.fromEnvironment('USE_REMOTE_BACKEND', defaultValue: true);

  final JournalAnalysisService _analysisService = JournalAnalysisService();
  final JournalRepository _repository = JournalRepository.instance;
  JournalRemoteApi? _remoteApi;

  SentimentInsight? _lastSentiment;
  RiskInsight? _lastRisk;
  JournalEntryInput? _lastInput;
  DateTime? _lastEntryDate;
  bool _updatingTriggers = false;
  String? _prefilledDayKey;

  @override
  void initState() {
    super.initState();
    _isDark = widget.isDarkMode;
    _setupRemote();
    _maybePrefillToday();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _analysisService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _isDark = Theme.of(context).brightness == Brightness.dark;
    final entries = _repository.entries;

    return Scaffold(
      backgroundColor: _isDark ? const Color(0xFF1B1F1C) : MindWellColors.cream,
      appBar: AppBar(
        title: Text(
          'Daily Journal',
          style: MindWellTypography.sectionSubtitle(
            color: _isDark ? Colors.white : MindWellColors.darkGray,
          ).copyWith(fontSize: 24),
        ),
        actions: [
          IconButton(
            tooltip: 'Insights',
            icon: const Icon(Icons.insights_outlined),
            onPressed: entries.isEmpty
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => JournalStatsPage(
                          repository: _repository,
                          onThemeChanged: widget.onThemeChanged,
                          onOpenJournal: (ctx) async {
                            Navigator.pop(ctx);
                          },
                        ),
                      ),
                    );
                  },
          ),
          Switch(
            value: _isDark,
            onChanged: (v) {
              setState(() => _isDark = v);
              widget.onThemeChanged(v);
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(_isDark ? '☾' : '☀'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(), // ✅ 总是可滚
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WeekStrip(
                  today: DateTime.now(),
                  repository: _repository,
                  isDark: _isDark,
                ),
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                const SizedBox(height: 20),
                Text(
                  'How are you feeling today?',
                  style: _sectionTitleStyle.copyWith(
                    color: _isDark ? Colors.white : MindWellColors.darkGray,
                  ),
                ),
                const SizedBox(height: 12),
                _MoodPicker(
                  mood: _mood,
                  isDark: _isDark,
                  onSelect: (value) => setState(() => _mood = value),
                ),
                const SizedBox(height: 24),

                // ---------- Tags ----------
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tags (optional)',
                      style: _sectionTitleStyle.copyWith(
                        color: _isDark ? Colors.white : MindWellColors.darkGray,
                      ),
                    ),
                    Text(
                      'Choose up to $_maxTags',
                      style: TextStyle(
                        fontSize: 12,
                        color: _isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final tag in _availableTags)
                      FilterChip(
                        selected: _selectedTags.contains(tag),
                        showCheckmark: false,
                        label: Text(_displayTag(tag)),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _selectedTags.contains(tag)
                              ? (_isDark ? Colors.black : Colors.white)
                              : (_isDark ? Colors.white70 : Colors.black87),
                        ),
                        onSelected: (value) {
                          setState(() {
                            if (value) {
                              if (_selectedTags.length < _maxTags) {
                                _selectedTags.add(tag);
                              }
                            } else {
                              _selectedTags.remove(tag);
                            }
                          });
                        },
                        backgroundColor: _isDark
                            ? const Color(0xFF2D332F)
                            : Colors.white,
                        selectedColor: _isDark
                            ? MindWellColors.accentCyan
                            : MindWellColors.accentBlue,
                        side: BorderSide(
                          color: _selectedTags.contains(tag)
                              ? (_isDark
                                    ? MindWellColors.accentCyan
                                    : MindWellColors.accentBlue)
                              : (_isDark
                                    ? const Color(0xFF3F4742)
                                    : const Color(0xFFE0E3DE)),
                        ),
                      ),

                    // ✅ 自定义 tag：+ Add
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                      onPressed: _onAddCustomTag,
                      backgroundColor: _isDark
                          ? const Color(0xFF2D332F)
                          : Colors.white,
                      side: BorderSide(
                        color: _isDark
                            ? const Color(0xFF3F4742)
                            : const Color(0xFFE0E3DE),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ---------- Note ----------
                Text(
                  'What would you like to note?',
                  style: _sectionTitleStyle.copyWith(
                    color: _isDark ? Colors.white : MindWellColors.darkGray,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: _isDark ? const Color(0xFF232825) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isDark
                          ? const Color(0xFF3F4742)
                          : const Color(0xFFD8DDD6),
                    ),
                    boxShadow: _isDark
                        ? null
                        : const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 15,
                              offset: Offset(0, 10),
                            ),
                          ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: TextField(
                    controller: _noteController,
                    minLines: 6,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      // ✅ 不要默认字
                      hintText: null,
                      border: InputBorder.none,
                    ),
                  ),
                ),

                if (_lastRisk != null && _lastSentiment != null) ...[
                  const SizedBox(height: 24),
                  _InsightCard(
                    sentiment: _lastSentiment!,
                    risk: _lastRisk!,
                    isDark: _isDark,
                    isUpdatingTriggers: _updatingTriggers,
                    onEditTriggers: _lastInput == null
                        ? null
                        : () => _openTriggerEditor(_lastRisk!.triggers),
                  ),
                ],

                const SizedBox(height: 24),

                // ✅ 保存按钮居中
                Center(
                  child: SizedBox(
                    width: 260,
                    child: FilledButton.icon(
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(_saving ? 'Saving...' : 'Save today’s entry'),
                      onPressed: _saving ? null : _submit,
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                if (entries.isNotEmpty) ...[
                  Text(
                    'Recent check-ins',
                    style: _sectionTitleStyle.copyWith(
                      color: _isDark ? Colors.white : MindWellColors.darkGray,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...entries.reversed
                      .take(4)
                      .map(
                        (entry) => _EntryTile(entry: entry, isDark: _isDark),
                      ),
                ],
                const SizedBox(height: 28), // ✅ 底部留白
              ],
            ),
          ),
        ),
      ),
    );
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
      _maybePrefillToday();
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
      final entries = await _remoteApi!.fetchEntries(widget.storeKey, limit: 30);
      _repository.replaceAll(entries);
      _maybePrefillToday();
      if (mounted) setState(() {});
    } catch (_) {
      // ignore remote errors
    }
  }

  void _maybePrefillToday() {
    final today = DateTime.now();
    final entry = _repository.entryOn(today);
    if (entry == null) return;

    final key = entry.dayKey;
    if (_prefilledDayKey == key) return;

    _prefilledDayKey = key;
    _mood = entry.mood;
    _selectedTags
      ..clear()
      ..addAll(entry.tags);
    _noteController.text = entry.note;
    _lastSentiment = entry.sentiment;
    _lastRisk = entry.risk;
    _lastInput = JournalEntryInput(
      mood: entry.mood,
      tags: entry.tags,
      note: entry.note,
      userId: widget.storeKey,
    );
    _lastEntryDate = entry.createdAt;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _onAddCustomTag() async {
    final controller = TextEditingController();
    final added = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add a tag'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: 'e.g., Exam, Family, Workout',
          ),
          onSubmitted: (_) => Navigator.of(ctx).pop(controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (added == null) return;
    final tag = _canonicalizeTag(added);
    if (tag.isEmpty) return;

    setState(() {
      // 大小写不敏感去重
      final exists = _availableTags.any(
        (t) => t.toLowerCase() == tag.toLowerCase(),
      );
      if (!exists) _availableTags.insert(0, tag);

      // 自动选中（不超过上限）
      if (_selectedTags.length < _maxTags) {
        _selectedTags.add(tag);
      }
    });
  }

  Future<void> _submit() async {
    final note = _noteController.text.trim();
    final normalizedTags = _selectedTags
        .map(_canonicalizeTag)
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();
    final entryDate = DateTime.now();
    final input = JournalEntryInput(
      mood: _mood,
      tags: normalizedTags,
      note: note,
      userId: widget.storeKey,
    );
    setState(() => _saving = true);

    try {
      if (_remoteApi != null) {
        final saved = await _remoteApi!.upsertEntry(
          userId: widget.storeKey,
          mood: _mood,
          tags: normalizedTags,
          note: note,
          entryDate: entryDate,
        );
        _repository.save(saved);
        _lastSentiment = saved.sentiment;
        _lastRisk = saved.risk;
        _lastInput = input;
        _lastEntryDate = entryDate;
        _prefilledDayKey = _dayKey(entryDate);
      } else {
        final (sentiment, risk, triggers) = await _analysisService
            .analyzeSentimentAndTriggers(note, input: input);

        final entry = JournalEntry(
          createdAt: entryDate,
          mood: input.mood,
          tags: input.tags,
          note: input.note,
          sentiment: sentiment,
          risk: risk,
          triggers: triggers,
        );
        _repository.save(entry);

        if (risk.level == 'high') {
          await _analysisService.sendAlert(input: input, risk: risk);
        }

        _lastSentiment = sentiment;
        _lastRisk = risk;
        _lastInput = input;
        _lastEntryDate = entryDate;
        _prefilledDayKey = _dayKey(entryDate);
      }

      if (!mounted) return;
      setState(() {
        _selectedTags.clear();
        _noteController.clear();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Entry saved')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save entry: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openTriggerEditor(List<String> currentTriggers) async {
    final controller = TextEditingController();
    final initial = currentTriggers
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .toSet();

    final result = await showModalBottomSheet<List<String>>(
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
                        child: const Text('Save triggers'),
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

    if (result != null) {
      await _applyTriggerOverride(result);
    }
  }

  Future<void> _applyTriggerOverride(List<String> triggers) async {
    final normalized = triggers
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();

    setState(() => _updatingTriggers = true);
    try {
      if (_remoteApi != null &&
          _lastInput != null &&
          _lastEntryDate != null) {
        final updated = await _remoteApi!.upsertEntry(
          userId: widget.storeKey,
          mood: _lastInput!.mood,
          tags: _lastInput!.tags,
          note: _lastInput!.note,
          entryDate: _lastEntryDate,
          manualTriggers: normalized,
        );
        _repository.save(updated);
        _lastSentiment = updated.sentiment;
        _lastRisk = updated.risk;
      } else {
        final latest =
            _repository.entries.isNotEmpty ? _repository.entries.last : null;
        if (latest != null) {
          final updated = latest.copyWith(
            risk: latest.risk.copyWith(triggers: normalized),
            triggers: normalized,
          );
          _repository.save(updated);
          _lastSentiment = updated.sentiment;
          _lastRisk = updated.risk;
        }
      }

      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Triggers updated')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update triggers: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingTriggers = false);
    }
  }
}

/* ------------------------ Mood Picker ------------------------ */

class _MoodPicker extends StatelessWidget {
  const _MoodPicker({
    required this.mood,
    required this.isDark,
    required this.onSelect,
  });

  final int mood;
  final bool isDark;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final isCompact = width < 360;
        final isMedium = width >= 360 && width < 540;
        final emojiSize = isCompact ? 56.0 : (isMedium ? 64.0 : 72.0);
        final labelFontSize = isCompact ? 12.0 : 14.0;
        final spacing = isCompact ? 12.0 : 16.0;
        final runSpacing = isCompact ? 16.0 : 20.0;
        final itemWidth = isCompact
            ? (width / 2) - spacing
            : (isMedium ? 110.0 : 120.0);
        final normalizedWidth = itemWidth.clamp(88.0, 140.0).toDouble();

        return Center(
          child: Wrap(
            spacing: spacing,
            runSpacing: runSpacing,
            alignment: WrapAlignment.center,
            children: _moodLabels.entries.map((entry) {
              final isSelected = mood == entry.key;
              return SizedBox(
                width: normalizedWidth,
                child: InkWell(
                  onTap: () => onSelect(entry.key),
                  borderRadius: BorderRadius.circular(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedScale(
                        scale: isSelected ? 1.12 : 1.0,
                        duration: const Duration(milliseconds: 130),
                        child: EmojiBlob(mood: entry.key, size: emojiSize),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        entry.value,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: labelFontSize,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? (isDark
                                    ? MindWellColors.accentCyan
                                    : MindWellColors.accentBlue)
                              : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

/* ------------------------ Week Strip ------------------------ */

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.today,
    required this.repository,
    required this.isDark,
  });

  final DateTime today;
  final JournalRepository repository;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final start = normalizedToday.subtract(
      Duration(days: normalizedToday.weekday % 7),
    );

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF232825) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF3F4742) : const Color(0xFFE4E6E0),
        ),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 14,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (index) {
          final day = start.add(Duration(days: index));
          final isToday = day == normalizedToday;
          final entry = repository.entryOn(day);
          final hasEntry = entry != null;
          final hasEntryToday = isToday && hasEntry;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _weekdayLabel(day.weekday),
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.4,
                  color: isToday
                      ? (isDark
                            ? MindWellColors.accentCyan
                            : MindWellColors.accentBlue)
                      : (isDark ? Colors.white54 : Colors.black54),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isToday ? 42 : 36,
                height: isToday ? 42 : 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isToday
                      ? (isDark ? const Color(0xFF1F241F) : Colors.white)
                      : (isDark
                            ? const Color(0xFF2D332F)
                            : const Color(0xFFF2F3EF)),
                  border: Border.all(
                    color: isToday
                        ? (isDark
                              ? MindWellColors.accentCyan
                              : MindWellColors.accentBlue)
                        : (isDark
                              ? const Color(0xFF3F4742)
                              : const Color(0xFFE0E3DE)),
                    width: isToday ? 2 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: hasEntry
                        ? (isDark
                              ? MindWellColors.accentCyan
                              : MindWellColors.accentBlue)
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
              if (hasEntryToday) ...[
                const SizedBox(height: 6),
                Container(
                  width: 24,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? MindWellColors.accentCyan
                        : MindWellColors.accentBlue,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ],
          );
        }),
      ),
    );
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'MON';
      case DateTime.tuesday:
        return 'TUE';
      case DateTime.wednesday:
        return 'WED';
      case DateTime.thursday:
        return 'THU';
      case DateTime.friday:
        return 'FRI';
      case DateTime.saturday:
        return 'SAT';
      default:
        return 'SUN';
    }
  }
}

/* ------------------------ Insight Card ------------------------ */

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.sentiment,
    required this.risk,
    required this.isDark,
    this.onEditTriggers,
    this.isUpdatingTriggers = false,
  });

  final SentimentInsight sentiment;
  final RiskInsight risk;
  final bool isDark;
  final VoidCallback? onEditTriggers;
  final bool isUpdatingTriggers;

  @override
  Widget build(BuildContext context) {
    final riskColor = _riskColor(risk.level);
    final riskScore = _riskScore100(risk.score);

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
                  color: Color(0x12000000),
                  blurRadius: 18,
                  offset: Offset(0, 12),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Latest insight',
            style: _sectionTitleStyle.copyWith(
              color: isDark ? Colors.white : MindWellColors.darkGray,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _InsightPill(
                label: 'Sentiment',
                value:
                    '${sentiment.label} ${(sentiment.confidence * 100).round()}%',
                color: isDark
                    ? MindWellColors.accentCyanSoft
                    : MindWellColors.accentBlueSoft,
              ),
              const SizedBox(width: 12),
              _InsightPill(
                label: 'Risk',
                value: '${risk.level.toUpperCase()} ${riskScore.round()}%',
                color: riskColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (risk.triggers.isNotEmpty || onEditTriggers != null) ...[
            Row(
              children: [
                Text(
                  'Possible triggers',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const Spacer(),
                if (onEditTriggers != null)
                  TextButton.icon(
                    onPressed:
                        isUpdatingTriggers ? null : () => onEditTriggers!(),
                    icon: isUpdatingTriggers
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.edit_outlined, size: 18),
                    label: Text(isUpdatingTriggers ? 'Saving...' : 'Edit'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (risk.triggers.isEmpty)
              Text(
                'No triggers detected yet.',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: risk.triggers
                    .map(
                      (t) => Chip(
                        label: Text(t),
                        backgroundColor: isDark
                            ? const Color(0xFF2D332F)
                            : const Color(0xFFF1F4F0),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 8),
          ],
          Text(
            risk.reason,
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
          ),
        ],
      ),
    );
  }

  Color _riskColor(String level) {
    switch (level) {
      case 'high':
        return const Color(0xFFE57373);
      case 'moderate':
        return const Color(0xFFF6C76B);
      default:
        return MindWellColors.lightGreen;
    }
  }
}

class _InsightPill extends StatelessWidget {
  const _InsightPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------ Entry Tile ------------------------ */

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.isDark});

  final JournalEntry entry;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final timestamp =
        '${entry.createdAt.year}-${entry.createdAt.month.toString().padLeft(2, '0')}-${entry.createdAt.day.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
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
                  blurRadius: 12,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      child: Row(
        children: [
          EmojiBlob(mood: entry.mood, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _moodLabels[entry.mood] ?? 'Mood',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : MindWellColors.darkGray,
                  ),
                ),
                const SizedBox(height: 4),
                if (entry.tags.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: entry.tags
                        .map(
                          (tag) => Chip(
                            label: Text(_displayTag(tag)),
                            visualDensity: VisualDensity.compact,
                            labelStyle: const TextStyle(fontSize: 12),
                          ),
                        )
                        .toList(),
                  ),
                if (entry.note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    entry.note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
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
