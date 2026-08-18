import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../domain/models/assessment.dart';
import '../application/services/assessment_api.dart';        // LocalRuleApi / RemoteAssessmentApi
import '../application/services/questionnaire_service.dart'; // QuestionnaireApi: PHQ-9 / GAD-7
import '../application/services/assessment_storage.dart';   // 历史记录存储
import 'widgets/chat_bubble.dart';
import 'widgets/history_list_page.dart'; // 历史记录列表页面

// flutter run -d chrome --web-port=8080 --web-hostname=127.0.0.1


class AssessmentPage extends StatefulWidget {
  const AssessmentPage({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
    this.initialMode = AssessmentMode.act,
    this.api, // 可注入 RemoteAssessmentApi（仅用于 CBT/ACT）
  });

  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final AssessmentMode initialMode;
  final AssessmentApi? api;

  @override
  State<AssessmentPage> createState() => _AssessmentPageState();
}

class _AssessmentPageState extends State<AssessmentPage> {
  late AssessmentState _state;
  late AssessmentApi _api;
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _waiting = false;
  // 从 CBT/ACT 进入问卷时的返回目标与一次性抑制 entry 递增
  AssessmentMode? _stageReturnTarget;
  bool _suppressEntryIncrementNextSwitch = false;

  // —— 问卷进度/结果（仅 PHQ-9 / GAD-7 用）——
  int _q = 0, _total = 0;
  bool _completed = false;
  int? _score;
  String? _severity;


  bool get _isQuestionnaire =>
      _state.mode == AssessmentMode.phq9 || _state.mode == AssessmentMode.gad7;

  bool get _showScaleButtonInStageMode {
    // 仅在 CBT/ACT 阶段显示手动触发按钮；问卷模式本身不显示该按钮
    final isStageMode = _state.mode == AssessmentMode.cbt || _state.mode == AssessmentMode.act;
    return isStageMode && _state.canTriggerScaleThisEntry;
  }

  // —— 工具：尽量宽松地把 meta 里的值转型，兼容 Map<String, dynamic>/String —— //
  int _toInt(Object? v, {int? fallback}) {
    if (v == null) return fallback ?? 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? (fallback ?? 0);
    if (v is bool) return v ? 1 : 0;
    return fallback ?? 0;
  }

  bool _toBool(Object? v, {bool fallback = false}) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase();
      return s == 'true' || s == '1' || s == 'yes';
    }
    return fallback;
  }

  String? _toStringOrNull(Object? v) => v?.toString();

  void _updateMeta(AssessmentMessage msg) {
  // 把可能为 null 的 meta 兜底成一个空 Map，避免在 null 上调用 containsKey
  final Map m = (msg.meta ?? const <String, dynamic>{});

  _q         = _toInt(m['q'],     fallback: _q);
  _total     = _toInt(m['total'], fallback: _total);
  _completed = _toBool(m['completed'], fallback: false);
  _score     = m.containsKey('score') ? _toInt(m['score']) : null;
  _severity  = _toStringOrNull(m['severity']);
  // 问卷完成：将“结果+报告”合并为一条消息（替换最后一条结果），避免重复
  if (_isQuestionnaire && _completed) {
    final report = _buildQuestionnaireReport(m);
    if (report.isNotEmpty && _state.messages.isNotEmpty) {
      // 写入历史
      final scaleStr = (m['scale'] ?? '').toString();
      final scoreVal = _toInt(m['score'], fallback: 0);
      final sevStr = (m['severity'] ?? '').toString();
      debugPrint('>>> 准备记录结果: scale=$scaleStr, score=$scoreVal, severity=$sevStr');
      _state.recordResult(scale: scaleStr, score: scoreVal, severity: sevStr, at: DateTime.now());
      debugPrint('>>> 记录完成，当前历史: PHQ-9=${_state.phq9History.length}, GAD-7=${_state.gad7History.length}');
      // 保存历史记录到持久化存储
      debugPrint('>>> 开始保存历史记录...');
      _saveHistoryToStorage().then((_) {
        debugPrint('>>> 保存历史记录回调完成');
        if (mounted) {
          setState(() {}); // 刷新 UI 以更新历史记录按钮状态
        }
      }).catchError((e) {
        debugPrint('>>> 保存历史记录失败: $e');
      });
      final hist = _state.getHistoryForScale(scaleStr)
          .map((e) => {
                'scale': e.scale,
                'at': e.at.toIso8601String(),
                'score': e.score,
                'severity': e.severity,
              })
          .toList(growable: false);
      _state.messages[_state.messages.length - 1] = AssessmentMessage(
        role: AgentRole.assistant,
        text: report,
        meta: {
          'type': 'report',
          'scale': m['scale']?.toString(),
          'score': m['score'],
          'severity': m['severity'],
          'range': m['range'],
          'total_items': m['total_items'] ?? (_total > 0 ? _total : null),
          'history': hist,
        },
      );
    }

    // 完成确认弹窗
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final isPhq9 = (m['scale'] ?? '').toString() == 'phq9';
      final score = _toInt(m['score'], fallback: 0);
      
      // GAD-7 重度得分（≥15）时自动推荐 PHQ-9
      if (!isPhq9 && score >= 15) {
        final recommendPhq9 = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('PHQ-9 recommended'),
            content: const Text('Based on a severe GAD-7 score, we recommend a PHQ-9 depression screening. Start now?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Later')),
              FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Start now')),
            ],
          ),
        );
        
        if (recommendPhq9 == true) {
          // 用户同意，自动切换到 CBT 模式并触发 PHQ-9
          _stageReturnTarget = null; // 清空返回目标
          _suppressEntryIncrementNextSwitch = false;
          _switchMode(AssessmentMode.cbt);
          // 延迟一点时间让模式切换完成，然后触发 PHQ-9
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _confirmAndStartPhq9(context);
            }
          });
          return; // 跳过后续的完成确认弹窗
        }
      }
      
      // 正常的完成确认弹窗
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Completed'),
          content: Text(isPhq9 ? 'PHQ‑9 questionnaire completed. You can review the result above.' : 'GAD‑7 questionnaire completed. You can review the result above.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('OK')),
          ],
        ),
      );
      if (!mounted) return;
      if (ok == true) {
        // 确认后返回来源阶段（或初始模式），允许再次测评：回到阶段会递增 entry，从而按钮重新出现
        if (_stageReturnTarget != null) {
          final target = _stageReturnTarget!;
          _stageReturnTarget = null;
          _suppressEntryIncrementNextSwitch = false; // 允许递增
          _switchMode(target);
        } else {
          // 无来源阶段（直接在问卷模式启动），回到初始模式
          _suppressEntryIncrementNextSwitch = false;
          _switchMode(widget.initialMode);
        }
      }
    });

    if (_stageReturnTarget != null) {
      _state.markMeasuredForThisEntry();
      // 等确认后切回，清空标记在上面处理
    }
  }
}

  String _buildQuestionnaireReport(Map meta) {
    final scale = (meta['scale'] ?? '').toString();
    if (scale != 'phq9' && scale != 'gad7') return '';
    final isPhq9 = scale == 'phq9';
    final title = isPhq9 ? 'PHQ‑9 Screening Report' : 'GAD‑7 Screening Report';
    final when = DateTime.now();
    final score = _toInt(meta['score'], fallback: 0);
    final totalItems = _toInt(meta['total_items'], fallback: _total > 0 ? _total : (isPhq9 ? 9 : 7));
    final sevKey = (meta['severity'] ?? '').toString();
    final sevLabel = _severityLabelEn(sevKey, isPhq9);
    final range = (meta['range'] ?? '').toString();
    final advise = isPhq9
        ? 'Advice: If moderate or above, consider professional evaluation. If you have self-harm thoughts, please contact professional or emergency services immediately.'
        : 'Advice: If moderate or above, consider professional support. Breathing and mindfulness can help as aids.';
    String two(int n) => n.toString().padLeft(2, '0');
    final whenStr = '${when.year}-${two(when.month)}-${two(when.day)} ${two(when.hour)}:${two(when.minute)}';
    
    // GAD-7 high score recommendation text
    String additionalAdvice = '';
    if (!isPhq9 && score >= 15) { // severe
      additionalAdvice = '\n\n💡 Recommendation:\n• Start a PHQ-9 screening\n• Seek professional mental health support\n• Practice mindfulness and breathing exercises';
    } else if (!isPhq9 && score >= 10) { // moderate+
      additionalAdvice = '\n\n💡 Consider:\n• PHQ-9 screening (tap "Start PHQ‑9")\n• Professional support\n• Mindfulness and breathing exercises';
    }
    
    return '$title\nTime: $whenStr\nItems: $totalItems\nTotal: $score / ${isPhq9 ? 27 : 21}\nSeverity: $sevLabel (range $range)\n\n$advise$additionalAdvice';
  }

  String _severityLabelEn(String key, bool isPhq9) {
    switch (key) {
      case 'minimal':
        return 'Minimal';
      case 'mild':
        return 'Mild';
      case 'moderate':
        return 'Moderate';
      case 'moderately_severe':
        return isPhq9 ? 'Moderately severe' : 'Severe';
      case 'severe':
        return 'Severe';
      default:
        return key.isEmpty ? '-' : key;
    }
  }

  // 根据模式创建对应的 API
  AssessmentApi _makeApi(AssessmentMode m) {
    if (m == AssessmentMode.phq9 || m == AssessmentMode.gad7) {
      return QuestionnaireApi(locale: 'en');
    }
    return widget.api ?? LocalRuleApi();
  }

  @override
  void initState() {
    super.initState();
    _state = AssessmentState(mode: widget.initialMode);
    _api = _makeApi(_state.mode);
    
    // 异步加载历史记录
    _loadHistoryFromStorage().then((_) {
      if (mounted) {
        setState(() {}); // 刷新 UI 以显示历史记录
      }
    });

    if (_isQuestionnaire) {
      // 问卷模式：简短引导 + 拉取第一题
      _state.add(AssessmentMessage(
        role: AgentRole.assistant,
        text: _state.mode == AssessmentMode.phq9
            ? "We will conduct the PHQ-9 screening. Please select 0/1/2/3 for each item."
            : "We will conduct the GAD-7 screening. Please select 0/1/2/3 for each item.",
      ));
      _prime();
    } else {
      // CBT/ACT 欢迎语（保持你的原逻辑）
      _state.add(AssessmentMessage(
        role: AgentRole.assistant,
        text: _state.mode == AssessmentMode.cbt
            ? "This is a CBT assessment dialogue. We will work together to review the situation–thoughts–evidence–new perspectives. To begin, you may describe a specific situation."
            : "This is an ACT assessment dialogue. We will practice present-moment awareness, clarify values, and plan small-step actions.",
      ));
      // 初次进入 CBT/ACT 也计作一次进入，允许本次手动测一次
      if (_state.mode == AssessmentMode.cbt || _state.mode == AssessmentMode.act) {
        _state.modeEntryId++;
        _state.add(AssessmentMessage(
          role: AgentRole.assistant,
          text: _state.mode == AssessmentMode.cbt
            ? 'If you like, we can do a PHQ-9 depression screening. It is for self-tracking only and not a diagnosis. Click "Start PHQ‑9" below when ready.'
            : 'If you like, we can do a GAD-7 anxiety screening. It is for self-tracking only and not a diagnosis. Click "Start GAD‑7" below when ready.',
        ));
      }
    }
  }

  @override
  void dispose() {
    // 保存当前状态
    _saveCurrentState();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // 首题/下一题（问卷模式下允许空输入触发）
  Future<void> _prime() async {
    setState(() => _waiting = true);
    final msg = await _api.reply(_state, "");
    setState(() {
      _state.add(msg);
      _updateMeta(msg);
      _waiting = false;
    });
    _jumpToBottom();
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();

    if (trimmed.isEmpty) {
      if (_isQuestionnaire) {
        return _prime(); // 问卷模式允许空输入触发下一题/首题
      }
      return;
    }

    setState(() {
      _state.add(AssessmentMessage(role: AgentRole.user, text: trimmed));
      _waiting = true;
    });
    _input.clear();
    _jumpToBottom();

    final msg = await _api.reply(_state, trimmed);
    setState(() {
      _state.add(msg);
      _updateMeta(msg); // 记录问卷进度与结果（CBT/ACT 不受影响）
      _waiting = false;
    });
    _jumpToBottom();
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _modeName(AssessmentMode m) => m.toString().split('.').last;

  void _switchMode(AssessmentMode m) {
    if (m == _state.mode) return;
    // 切换模式前保存历史记录（不等待完成，避免阻塞 UI）
    _saveHistoryToStorage().catchError((e) {
      debugPrint('切换模式时保存失败: $e');
    });
    
    setState(() {
      _state.mode = m;
      _state.stage = 0;
      // 每次切换 CBT/ACT/问卷 模式都重建 API
      _api = _makeApi(m);
      // 清空问卷进度摘要
      _q = 0;
      _total = 0;
      _completed = false;
      _score = null;
      _severity = null;

      _state.add(AssessmentMessage(
        role: AgentRole.system,
        text: 'Switched to ${_modeName(m).toUpperCase()} mode.',
        meta: {'mode': _modeName(m)},
      ));

      // 若切换到 CBT 或 ACT，视为"进入该阶段一次"，entry 递增
      if (m == AssessmentMode.cbt || m == AssessmentMode.act) {
        if (!_suppressEntryIncrementNextSwitch) {
          _state.modeEntryId++;
        }
        _suppressEntryIncrementNextSwitch = false; // 仅抑制一次
        _state.add(AssessmentMessage(
          role: AgentRole.assistant,
          text: m == AssessmentMode.cbt
              ? 'If you like, we can do a PHQ-9 depression screening. It is for self-tracking only and not a diagnosis. Click "Start PHQ‑9" below when ready.'
              : 'If you like, we can do a GAD-7 anxiety screening. It is for self-tracking only and not a diagnosis. Click "Start GAD‑7" below when ready.',
        ));
      }
    });

    if (_isQuestionnaire) {
      _state.add(AssessmentMessage(
        role: AgentRole.assistant,
        text: m == AssessmentMode.phq9
            ? "We will be conducting a PHQ-9 screening. Please select 0/1/2/3 according to the frequency of distress for each question."
            : "We will be conducting a GAD-7 screening. Please select 0/1/2/3 according to the frequency of distress for each question.",
      ));
      _prime();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assessment'),
        actions: [
          // 历史记录按钮
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'View History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HistoryListPage(),
                ),
              ).then((_) {
                // 返回后重新加载历史记录
                _loadHistoryFromStorage().then((_) {
                  if (mounted) {
                    setState(() {}); // 刷新 UI
                  }
                });
              });
            },
          ),
          PopupMenuButton<AssessmentMode>(
            tooltip: 'Switch mode',
            initialValue: _state.mode,
            onSelected: _switchMode,
            itemBuilder: (_) => const [
              PopupMenuItem(value: AssessmentMode.cbt,  child: Text('CBT')),
              PopupMenuItem(value: AssessmentMode.act,  child: Text('ACT')),
            ],
            icon: const Icon(Icons.tune),
          ),
          Switch(value: isDark, onChanged: widget.onThemeChanged),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(isDark ? '☾' : '☀'),
          ),
        ],
      ),
      body: Column(
        children: [
          // —— 问卷摘要条（有进度时显示）——
          if (_isQuestionnaire && _total > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(value: _q / _total),
                  const SizedBox(height: 6),
                  Text('Progress: $_q / $_total'),
                  if (_completed) ...[
                    const SizedBox(height: 6),
                    Text('Score: ${_score ?? '-'}   Severity: ${_severity ?? '-'}'),
                  ],
                ],
              ),
            ),

          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: _state.messages.length + (_waiting ? 1 : 0),
              itemBuilder: (_, i) {
                if (_waiting && i == _state.messages.length) {
                  return const TypingBubble();
                }
                final m = _state.messages[i];
                return ChatBubble(message: m);
              },
            ),
          ),

          // —— 建议/选项区 —— //
          if (_isQuestionnaire)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ElevatedButton(
                        onPressed: () => _send('0'),
                        child: const Text('0  Not at all')),
                    ElevatedButton(
                        onPressed: () => _send('1'),
                        child: const Text('1  Several days')),
                    ElevatedButton(
                        onPressed: () => _send('2'),
                        child: const Text('2  More than half the days')),
                    ElevatedButton(
                        onPressed: () => _send('3'),
                        child: const Text('3  Nearly every day')),
                  ],
                ),
              ),
            )
          else if (_showScaleButtonInStageMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    FilledButton.icon(
                      onPressed: () => (_state.mode == AssessmentMode.cbt)
                          ? _confirmAndStartPhq9(context)
                          : _confirmAndStartGad7(context),
                      icon: Icon(_state.mode == AssessmentMode.cbt ? Icons.favorite : Icons.spa),
                      label: Text(_state.mode == AssessmentMode.cbt ? 'Start PHQ‑9' : 'Start GAD‑7'),
                    ),
                    // Separate trend buttons for PHQ-9 and GAD-7
                    Builder(builder: (ctx) {
                      final phqHist = _state.getHistoryForScale('phq9');
                      return OutlinedButton.icon(
                        onPressed: phqHist.isNotEmpty ? () => _showTrendDialogForScale('phq9') : null,
                        icon: const Icon(Icons.show_chart),
                        label: const Text('PHQ‑9 Trend'),
                      );
                    }),
                    Builder(builder: (ctx) {
                      final gadHist = _state.getHistoryForScale('gad7');
                      return OutlinedButton.icon(
                        onPressed: gadHist.isNotEmpty ? () => _showTrendDialogForScale('gad7') : null,
                        icon: const Icon(Icons.show_chart),
                        label: const Text('GAD‑7 Trend'),
                      );
                    }),
                  ],
                ),
              ),
            ),

          // —— 输入区 —— //
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: _isQuestionnaire
                            ? 'Tap 0/1/2/3 above, or type 0/1/2/3 / phrase here'
                            : 'Enter your thoughts',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: _send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _waiting ? null : () => _send(_input.text),
                    icon: const Icon(Icons.send),
                    label: const Text('Send'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// —— 触发问卷（从 CBT/ACT 切入）——
extension _StageScaleTrigger on _AssessmentPageState {
  void _startScale(AssessmentMode nextMode) {
    _stageReturnTarget = _state.mode; // 返回到来源阶段
    _suppressEntryIncrementNextSwitch = true; // 抑制下一次 entry 自增
    _switchMode(nextMode);
  }

  Future<void> _confirmAndStartPhq9(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start PHQ‑9?'),
        content: const Text('PHQ‑9 is for self-screening and tracking only, not a diagnosis. You can stop at any time. Start now?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Start now')),
        ],
      ),
    );
    if (ok == true) {
      _startScale(AssessmentMode.phq9);
    }
  }

  Future<void> _confirmAndStartGad7(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start GAD‑7?'),
        content: const Text('GAD‑7 is for self-screening and tracking only, not a diagnosis. You can stop at any time. Start now?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Start now')),
        ],
      ),
    );
    if (ok == true) {
      _startScale(AssessmentMode.gad7);
    }
  }

  void _showTrendDialogForScale(String scale) {
    final isPhq9 = scale == 'phq9';
    final maxScore = isPhq9 ? 27 : 21;
    final hist = _state.getHistoryForScale(scale);
    final sortedHist = List<AssessmentResult>.from(hist)
      ..sort((a, b) => a.at.compareTo(b.at));
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isPhq9 ? 'PHQ‑9 Trend' : 'GAD‑7 Trend'),
        content: SizedBox(
          width: 600,
          height: 400,
          child: sortedHist.length < 2
              ? const Center(child: Text('Not enough data. At least 2 records required.'))
              : _TrendChart(history: sortedHist, maxScore: maxScore, isPhq9: isPhq9),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        ],
      ),
    );
  }
}

// Custom painter to draw score labels on data points
class _ScoreLabelPainter extends CustomPainter {
  _ScoreLabelPainter({
    required this.spots,
    required this.history,
    required this.maxScore,
    required this.textColor,
    required this.chartSize,
  });

  final List<FlSpot> spots;
  final List<AssessmentResult> history;
  final int maxScore;
  final Color textColor;
  final Size chartSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (spots.isEmpty) return;

    final textStyle = TextStyle(
      color: textColor,
      fontSize: 12,
      fontWeight: FontWeight.bold,
    );

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // fl_chart's layout calculation
    // bottomTitles reservedSize: 40
    // fl_chart has minimal internal padding, mostly just the border
    const bottomTitleHeight = 40.0;
    const leftPadding = 0.0; // No left titles, so minimal padding
    const topPadding = 0.0; // No top titles
    const rightPadding = 0.0; // No right titles
    const horizontalPadding = leftPadding + rightPadding;
    
    // Calculate the actual chart drawing area
    // fl_chart draws the border inside, so we account for it
    final chartDrawingWidth = chartSize.width - horizontalPadding;
    final chartDrawingHeight = chartSize.height - bottomTitleHeight;
    
    // Starting position of chart drawing area
    final chartStartX = leftPadding;
    final chartStartY = topPadding;

    for (int i = 0; i < spots.length; i++) {
      final spot = spots[i];
      final score = history[i].score;

      // Calculate position matching fl_chart's coordinate system
      // X: normalized from 0 to (history.length - 1)
      final xRatio = spots.length > 1 ? spot.x / (spots.length - 1) : 0.5;
      // Y: normalized from 0 to maxScore, inverted (0 at top, maxScore at bottom)
      final yRatio = 1.0 - (spot.y / maxScore);
      
      // Calculate actual pixel position
      final x = chartStartX + xRatio * chartDrawingWidth;
      final y = chartStartY + yRatio * chartDrawingHeight;

      // Draw score text above the point
      textPainter.text = TextSpan(
        text: score.toString(),
        style: textStyle,
      );
      textPainter.layout();

      // Center the text horizontally above the point
      final textX = x - textPainter.width / 2;
      final textY = y - 18; // Position above the point (18px offset for better visibility)

      // Always draw the text (remove bounds check to ensure visibility)
      textPainter.paint(canvas, Offset(textX, textY));
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreLabelPainter oldDelegate) {
    return oldDelegate.spots != spots ||
        oldDelegate.history != history ||
        oldDelegate.maxScore != maxScore ||
        oldDelegate.textColor != textColor ||
        oldDelegate.chartSize != chartSize;
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({
    required this.history,
    required this.maxScore,
    required this.isPhq9,
  });
  
  final List<AssessmentResult> history;
  final int maxScore;
  final bool isPhq9;

  @override
  Widget build(BuildContext context) {
    // Convert history records to chart data points
    final spots = history
        .asMap()
        .entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value.score.toDouble()))
        .toList();

    // Format date function
    String formatDate(DateTime date) {
      return '${date.month}/${date.day}';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  enabled: false,
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxScore > 10 ? 5.0 : 2.0,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withValues(alpha: 0.2),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: 1.0, // Show every data point
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < history.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              formatDate(history[index].at),
                              style: TextStyle(
                                color: Theme.of(context).textTheme.bodySmall?.color,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                minX: 0,
                maxX: (history.length - 1).toDouble(),
                minY: 0,
                maxY: maxScore.toDouble(),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: Theme.of(context).colorScheme.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Theme.of(context).colorScheme.primary,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
            // Overlay score labels on each data point
            CustomPaint(
              painter: _ScoreLabelPainter(
                spots: spots,
                history: history,
                maxScore: maxScore,
                textColor: Theme.of(context).colorScheme.onSurface,
                chartSize: Size(constraints.maxWidth, constraints.maxHeight),
              ),
            ),
          ],
        );
      },
    );
  }
}

// —— 历史记录持久化功能 ——
extension _HistoryPersistence on _AssessmentPageState {
  /// 从存储中加载历史记录
  /// 返回加载的历史记录数据
  Future<({List<AssessmentResult> phq9History, List<AssessmentResult> gad7History})> _loadHistoryFromStorage() async {
    try {
      final history = await AssessmentStorage.loadHistory();
      // 将加载的历史记录添加到状态中（使用 clear 和 addAll 确保完全替换）
      _state.phq9History.clear();
      _state.phq9History.addAll(history.phq9History);
      _state.gad7History.clear();
      _state.gad7History.addAll(history.gad7History);
      debugPrint('✓ 加载历史记录: PHQ-9 ${history.phq9History.length} 条, GAD-7 ${history.gad7History.length} 条');
      return (
        phq9History: history.phq9History,
        gad7History: history.gad7History,
      );
    } catch (e) {
      debugPrint('✗ 加载历史记录失败: $e');
      return (
        phq9History: <AssessmentResult>[],
        gad7History: <AssessmentResult>[],
      );
    }
  }

  /// 保存历史记录到存储
  Future<void> _saveHistoryToStorage() async {
    try {
      // 确保使用当前最新的历史记录数据
      final phq9Count = _state.phq9History.length;
      final gad7Count = _state.gad7History.length;
      
      await AssessmentStorage.saveHistory(
        phq9History: List.from(_state.phq9History), // 创建副本以避免并发问题
        gad7History: List.from(_state.gad7History),
      );
      debugPrint('✓ 保存历史记录成功: PHQ-9 $phq9Count 条, GAD-7 $gad7Count 条');
    } catch (e) {
      debugPrint('✗ 保存历史记录失败: $e');
      debugPrint('错误堆栈: ${StackTrace.current}');
    }
  }

  /// 保存当前状态（在 dispose 时调用）
  /// 注意：dispose 中不能使用 await，所以使用同步方式触发保存
  /// 但 SharedPreferences 的保存通常是立即写入的，应该不会丢失数据
  void _saveCurrentState() {
    // 保存历史记录（不等待完成，因为在 dispose 中）
    _saveHistoryToStorage();
  }
}



