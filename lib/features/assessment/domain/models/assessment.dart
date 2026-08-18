import 'package:flutter/material.dart';

// enum AgentRole { user, assistant, system }
// enum AssessmentMode { cbt, act, phq9, gad7 }

enum AssessmentMode { cbt, act, phq9, gad7 }
enum AgentRole { system, user, assistant } // 切模式时你用到 system


@immutable
class AssessmentMessage {
  final AgentRole role;
  final String text;
  final DateTime ts;
  final Map<String, dynamic>? meta;
  AssessmentMessage({
    required this.role,
    required this.text,
    DateTime? ts,
    this.meta,
  }) : ts = ts ?? DateTime.now();
}

class AssessmentState {
  AssessmentState({required this.mode}) : messages = <AssessmentMessage>[];
  AssessmentMode mode;
  final List<AssessmentMessage> messages;

  // 简单阶段指针，便于基于规则的流程，也方便未来把对话状态序列化给大模型
  int stage = 0;

  void add(AssessmentMessage m) => messages.add(m);

  // —— 每次进入 CBT/ACT 的一次性量表触发控制 ——
  // 进入某阶段（外部切换 mode）时，应递增 entryId，用于区分“本次进入”。
  int modeEntryId = 0;
  final Set<String> measuredKeys = <String>{};

  // 当前阶段待触发的量表（CBT->PHQ-9，ACT->GAD-7；其余为空）
  String get pendingScale {
    switch (mode) {
      case AssessmentMode.cbt:
        return 'phq9';
      case AssessmentMode.act:
        return 'gad7';
      default:
        return '';
    }
  }

  // 本次进入该阶段是否还可以手动触发量表
  bool get canTriggerScaleThisEntry {
    if (pendingScale.isEmpty) return false;
    final key = '${mode.name}#$modeEntryId';
    return !measuredKeys.contains(key);
  }

  // 量表完成后标记（一次性）
  void markMeasuredForThisEntry() {
    if (pendingScale.isEmpty) return;
    measuredKeys.add('${mode.name}#$modeEntryId');
  }

  // —— 历史成绩（分别存储 PHQ-9 和 GAD-7 的结果） ——
  final List<AssessmentResult> phq9History = <AssessmentResult>[];
  final List<AssessmentResult> gad7History = <AssessmentResult>[];
  
  void recordResult({required String scale, required int score, required String severity, required DateTime at}) {
    final result = AssessmentResult(scale: scale, score: score, severity: severity, at: at);
    if (scale == 'phq9') {
      phq9History.add(result);
    } else if (scale == 'gad7') {
      gad7History.add(result);
    }
  }
  
  // 获取指定量表的历史记录
  List<AssessmentResult> getHistoryForScale(String scale) {
    if (scale == 'phq9') {
      return List.from(phq9History);
    } else if (scale == 'gad7') {
      return List.from(gad7History);
    }
    return [];
  }

  // —— 状态保存/恢复功能 ——
  Map<String, dynamic> toJson() {
    return {
      'mode': mode.name,
      'stage': stage,
      'modeEntryId': modeEntryId,
      'measuredKeys': measuredKeys.toList(),
      'phq9History': phq9History.map((e) => {
        'scale': e.scale,
        'score': e.score,
        'severity': e.severity,
        'at': e.at.toIso8601String(),
      }).toList(),
      'gad7History': gad7History.map((e) => {
        'scale': e.scale,
        'score': e.score,
        'severity': e.severity,
        'at': e.at.toIso8601String(),
      }).toList(),
    };
  }

  static AssessmentState fromJson(Map<String, dynamic> json) {
    final state = AssessmentState(mode: AssessmentMode.values.firstWhere((e) => e.name == json['mode']));
    state.stage = json['stage'] ?? 0;
    state.modeEntryId = json['modeEntryId'] ?? 0;
    state.measuredKeys.addAll((json['measuredKeys'] as List?)?.cast<String>() ?? []);
    
    // 分别恢复 PHQ-9 和 GAD-7 的历史记录
    final phq9HistoryJson = json['phq9History'] as List? ?? [];
    for (final item in phq9HistoryJson) {
      if (item is Map) {
        state.phq9History.add(AssessmentResult(
          scale: item['scale'] ?? '',
          score: item['score'] ?? 0,
          severity: item['severity'] ?? '',
          at: DateTime.tryParse(item['at'] ?? '') ?? DateTime.now(),
        ));
      }
    }
    
    final gad7HistoryJson = json['gad7History'] as List? ?? [];
    for (final item in gad7HistoryJson) {
      if (item is Map) {
        state.gad7History.add(AssessmentResult(
          scale: item['scale'] ?? '',
          score: item['score'] ?? 0,
          severity: item['severity'] ?? '',
          at: DateTime.tryParse(item['at'] ?? '') ?? DateTime.now(),
        ));
      }
    }
    
    return state;
  }
}

@immutable
class AssessmentResult {
  const AssessmentResult({required this.scale, required this.score, required this.severity, required this.at});
  final String scale; // 'phq9' | 'gad7'
  final int score;    // 0..27 / 0..21
  final String severity; // minimal/mild/moderate/moderately_severe/severe
  final DateTime at;
}
