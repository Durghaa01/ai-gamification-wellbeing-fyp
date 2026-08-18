// lib/services/questionnaire_service.dart
import '../../domain/models/assessment.dart';
import 'assessment_api.dart';

/// PHQ-9 / GAD-7 questionnaire engine with scoring and severity.
/// - Drop-in for AssessmentMode.phq9 / .gad7
/// - Keeps progress in an Expando attached to AssessmentState
class QuestionnaireApi implements AssessmentApi {
  QuestionnaireApi({
    this.locale = 'en',
    this.simulatedLatency = const Duration(milliseconds: 150),
  });

  final String locale;
  final Duration simulatedLatency;

  static final Expando<_RunCache> _session = Expando<_RunCache>('q_session');

  @override
  Future<AssessmentMessage> reply(AssessmentState state, String userInput) async {
    await Future<void>.delayed(simulatedLatency);

    if (state.mode != AssessmentMode.phq9 && state.mode != AssessmentMode.gad7) {
      return AssessmentMessage(
        role: AgentRole.assistant,
        text: 'QuestionnaireApi can only handle PHQ-9 / GAD-7 modes.',
        meta: {'error': 'mode_not_supported', 'mode': state.mode.toString()},
      );
    }

    // init or realign cache to current mode
    final desired = state.mode == AssessmentMode.phq9 ? _Scale.phq9 : _Scale.gad7;
    var cache = _session[state];
    if (cache == null || cache.scale != desired) {
      cache = _RunCache(scale: desired);
      _session[state] = cache;
    }

    // first question
    if (cache.index == 0 && cache.answers.isEmpty && state.stage == 0) {
      state.stage = 1;
      return _questionMessage(cache);
    }

    // parse answer 0..3
    final parsed = _parseAnswer(userInput);
    if (parsed == null) {
      return AssessmentMessage(
        role: AgentRole.assistant,
        text: _rePrompt(cache),
        meta: {
          'scale': cache.scale.name,
          'q': cache.index + 1,
          'total': cache.total,
          'expect': '0..3 or option keyword',
        },
      );
    }

    cache.answers.add(parsed);

    // next or finish
    if (cache.index + 1 < cache.total) {
      cache.index++;
      state.stage = cache.index + 1;
      return _questionMessage(cache);
    } else {
      final total = cache.answers.fold<int>(0, (a, b) => a + b);
      final severity = cache.scale == _Scale.phq9 ? _phq9Severity(total) : _gad7Severity(total);
      final result = _buildResult(cache, total, severity);

      final meta = {
        'scale': cache.scale.name,
        'score': total,
        'severity': severity.key,
        'range': severity.range,
        'answers': List<int>.from(cache.answers),
        'completed': true,
        'total_items': cache.total,
      };

      // reset for next run: clear cache so next start aligns with current mode
      _session[state] = null;
      state.stage = 0;

      return AssessmentMessage(role: AgentRole.assistant, text: result, meta: meta);
    }
  }

  AssessmentMessage _questionMessage(_RunCache cache) {
    final itemText = _itemText(cache);
    final options = _optionText(locale);
    final progress = '[${cache.index + 1}/${cache.total}]';
    return AssessmentMessage(
      role: AgentRole.assistant,
      text: '${cache.title} $progress\n\n$itemText\n\n$options\n\n${_answerHint(locale)}',
      meta: {
        'scale': cache.scale.name,
        'q': cache.index + 1,
        'total': cache.total,
        'score_so_far': cache.answers.fold<int>(0, (a, b) => a + b),
      },
    );
  }

  String _rePrompt(_RunCache cache) {
    final options = _optionText(locale);
    return 'Please reply with 0, 1, 2, or 3 (or the option text).\n\n$options\n\n${_answerHint(locale)}';
  }

  String _itemText(_RunCache cache) {
    final list = cache.scale == _Scale.phq9 ? _phq9Items : _gad7Items;
    return list[cache.index];
  }

  String _optionText(String locale) => '0) Not at all\n1) Several days\n2) More than half the days\n3) Nearly every day';

  String _answerHint(String locale) => 'Tip: you can answer with 0/1/2/3 or the phrase (e.g., "Several days").';

  String _buildResult(_RunCache cache, int total, _Severity sev) {
    final header = _t(locale, {
      'en': '**${cache.title}** result',
      'zh': '**${cache.title}** 结果',
    });
    final scoreLine = _t(locale, {
      'en': 'Total score: $total  (range ${sev.range})',
      'zh': '总分：$total（范围 ${sev.range}）',
    });
    final sevLine = _t(locale, {
      'en': 'Severity: **${sev.labelEn}**',
      'zh': '严重程度：**${sev.labelZh}**',
    });
    final note = _t(locale, {
      'en':
          '\n\n*Note: This screening is not a diagnosis. If the score is moderate or above, consider consulting a clinician.*',
      'zh': '\n\n*提示：本量表仅用于筛查，不能替代专业诊断。如得分达到中度或以上，建议咨询专业人士。*',
    });
    return '$header\n$scoreLine\n$sevLine$note';
  }
}

// ===== Internals =====

enum _Scale { phq9, gad7 }

class _RunCache {
  _RunCache({required this.scale})
      : index = 0,
        answers = <int>[];
  final _Scale scale;
  int index; // 0..N-1
  final List<int> answers; // 0..3
  int get total => scale == _Scale.phq9 ? _phq9Items.length : _gad7Items.length;

  String get title => scale == _Scale.phq9 ? _phq9Title : _gad7Title;
}

// ---- Item banks (EN + ZH lines) ----

const String _phq9Title = 'PHQ-9';
const String _gad7Title = 'GAD-7';
// 简短窗口说明（题1行首用）
const String _phq9Instruction = 'Over the last 2 weeks';
const String _gad7Instruction = 'Over the last 2 weeks';

final List<String> _phq9Items = [
  '1) $_phq9Instruction\n— Little interest or pleasure in doing things',
  '2) — Feeling down, depressed, or hopeless',
  '3) — Trouble falling or staying asleep, or sleeping too much',
  '4) — Feeling tired or having little energy',
  '5) — Poor appetite or overeating',
  '6) — Feeling bad about yourself — or that you are a failure or have let yourself or your family down',
  '7) — Trouble concentrating on things, such as reading the newspaper or watching television',
  '8) — Moving or speaking so slowly that other people could have noticed; or the opposite — being so fidgety or restless that you have been moving around a lot more than usual',
  '9) — Thoughts that you would be better off dead or of hurting yourself in some way',
];

final List<String> _gad7Items = [
  '1) $_gad7Instruction\n— Feeling nervous, anxious, or on edge',
  '2) — Not being able to stop or control worrying',
  '3) — Worrying too much about different things',
  '4) — Trouble relaxing',
  '5) — Being so restless that it is hard to sit still',
  '6) — Becoming easily annoyed or irritable',
  '7) — Feeling afraid as if something awful might happen',
];

// ---- Severity mapping ----

class _Severity {
  const _Severity({
    required this.key,
    required this.range,
    required this.labelEn,
    required this.labelZh,
  });
  final String key;   // minimal, mild, moderate, moderately_severe, severe
  final String range; // e.g., 0–4
  final String labelEn;
  final String labelZh;
}

_Severity _phq9Severity(int score) {
  if (score <= 4) return const _Severity(key: 'minimal', range: '0–4', labelEn: 'Minimal', labelZh: '最轻');
  if (score <= 9) return const _Severity(key: 'mild', range: '5–9', labelEn: 'Mild', labelZh: '轻度');
  if (score <= 14) return const _Severity(key: 'moderate', range: '10–14', labelEn: 'Moderate', labelZh: '中度');
  if (score <= 19) return const _Severity(key: 'moderately_severe', range: '15–19', labelEn: 'Moderately severe', labelZh: '中重度');
  return const _Severity(key: 'severe', range: '20–27', labelEn: 'Severe', labelZh: '重度');
}

_Severity _gad7Severity(int score) {
  if (score <= 4) return const _Severity(key: 'minimal', range: '0–4', labelEn: 'Minimal', labelZh: '最轻');
  if (score <= 9) return const _Severity(key: 'mild', range: '5–9', labelEn: 'Mild', labelZh: '轻度');
  if (score <= 14) return const _Severity(key: 'moderate', range: '10–14', labelEn: 'Moderate', labelZh: '中度');
  return const _Severity(key: 'severe', range: '15–21', labelEn: 'Severe', labelZh: '重度');
}

// ---- Parsing ----

int? _parseAnswer(String raw) {
  if (raw.isEmpty) return null;
  final s = raw.trim().toLowerCase();

  // numerics
  final n = int.tryParse(s);
  if (n != null && n >= 0 && n <= 3) return n;

  // english keywords
  if (s.contains('not at all')) return 0;
  if (s.contains('several')) return 1; // several days
  if (s.contains('more than half')) return 2;
  if (s.contains('nearly') || s.contains('almost every') || s.contains('every day')) return 3;

  // chinese keywords
  if (s.contains('完全没有')) return 0;
  if (s.contains('好几天')) return 1;
  if (s.contains('超过一半') || s.contains('一半以上')) return 2;
  if (s.contains('几乎每天')) return 3;

  return null;
}

String _t(String locale, Map<String, String> byLang) {
  if (locale.startsWith('zh')) return byLang['zh'] ?? byLang['en']!;
  return byLang['en']!;
}





// // import 'dart:async';

// import '../models/assessment.dart';
// import 'assessment_api.dart';

// // ===== Types assumed from your project =====
// // Adjust imports to your actual locations.
// // These minimal stubs let this file compile in isolation.
// // Remove them if you already have the real ones in your codebase.
// // -------------------------------------------
// // BEGIN STUBS
// // enum AgentRole { assistant, user }

// // enum AssessmentMode { cbt, act, phq9, gad7 }

// // class AssessmentMessage {
// //   AssessmentMessage({
// //     required this.role,
// //     required this.text,
// //     this.meta = const {},
// //   });
// //   final AgentRole role;
// //   final String text;
// //   final Map<String, dynamic> meta;
// // }

// // class AssessmentState {
// //   AssessmentState({
// //     required this.mode,
// //     this.stage = 0,
// //   });
// //   AssessmentMode mode;
// //   int stage;
// //   // If your real type has more fields (e.g., messages), keep them.
// // }

// // abstract class AssessmentApi {
// //   Future<AssessmentMessage> reply(AssessmentState state, String userInput);
// // }
// // // END STUBS
// // -------------------------------------------

// /// PHQ-9 / GAD-7 questionnaire engine with scoring and severity.
// /// - Works as an AssessmentApi drop-in for `AssessmentMode.phq9` and `AssessmentMode.gad7`.
// /// - Stores per-session progress via `Expando` attached to `AssessmentState` (no schema changes).
// /// - Parsing is tolerant: accepts 0-3, option keywords (EN/ZH), and common phrases.


// class QuestionnaireApi implements AssessmentApi {
//   QuestionnaireApi({this.locale = 'en', this.simulatedLatency = const Duration(milliseconds: 150)});

//   final String locale;
//   final Duration simulatedLatency;

//   // Per-state run cache
//   static final Expando<_RunCache> _session = Expando<_RunCache>('q_session');

//   @override
//   Future<AssessmentMessage> reply(AssessmentState state, String userInput) async {
//     await Future<void>.delayed(simulatedLatency);

//     if (state.mode != AssessmentMode.phq9 && state.mode != AssessmentMode.gad7) {
//       return AssessmentMessage(
//         role: AgentRole.assistant,
//         text: 'QuestionnaireApi can only handle PHQ-9 / GAD-7 modes.',
//         meta: {'error': 'mode_not_supported', 'mode': state.mode.name},
//       );
//     }

//     // Init cache if not exists
//     final cache = _session[state] ??= _RunCache(
//       scale: state.mode == AssessmentMode.phq9 ? _Scale.phq9 : _Scale.gad7,
//     );

//     // If we are at the start (no answers yet), ask first question
//     if (cache.index == 0 && cache.answers.isEmpty && state.stage == 0) {
//       state.stage = 1; // align with your previous pattern (stage increments on first prompt)
//       return _questionMessage(cache);
//     }

//     // If awaiting an answer, parse the user input to a score 0..3
//     final parsed = _parseAnswer(userInput);
//     if (parsed == null) {
//       // Reprompt with guidance
//       return AssessmentMessage(
//         role: AgentRole.assistant,
//         text: _rePrompt(cache),
//         meta: {
//           'scale': cache.scale.name,
//           'q': cache.index + 1,
//           'total': cache.total,
//           'expect': '0..3 or option keyword',
//         },
//       );
//     }

//     cache.answers.add(parsed);

//     // Move to next or finish
//     if (cache.index + 1 < cache.total) {
//       cache.index++;
//       state.stage = cache.index + 1; // 1-based for UI friendliness
//       return _questionMessage(cache);
//     } else {
//       // Completed: compute score and severity
//       final total = cache.answers.fold<int>(0, (a, b) => a + b);
//       final severity = cache.scale == _Scale.phq9 ? _phq9Severity(total) : _gad7Severity(total);
//       final result = _buildResult(cache, total, severity);

//       // Reset stage but keep session if you want to review; here we clear for next run
//       final meta = {
//         'scale': cache.scale.name,
//         'score': total,
//         'severity': severity.key,
//         'range': severity.range,
//         'answers': List<int>.from(cache.answers),
//         'completed': true,
//         'total_items': cache.total,
//       };

//       // Clear session for a fresh start next time
//       _session[state] = _RunCache(scale: cache.scale);
//       state.stage = 0;

//       return AssessmentMessage(
//         role: AgentRole.assistant,
//         text: result,
//         meta: meta,
//       );
//     }
//   }

//   AssessmentMessage _questionMessage(_RunCache cache) {
//     final itemText = _itemText(cache);
//     final options = _optionText(locale);
//     final progress = '[${cache.index + 1}/${cache.total}]';

//     return AssessmentMessage(
//       role: AgentRole.assistant,
//       text: '${cache.title} ${progress}\n\n${itemText}\n\n${options}\n\n${_answerHint(locale)}',
//       meta: {
//         'scale': cache.scale.name,
//         'q': cache.index + 1,
//         'total': cache.total,
//         'score_so_far': cache.answers.fold<int>(0, (a, b) => a + b),
//       },
//     );
//   }

//   String _rePrompt(_RunCache cache) {
//     final options = _optionText(locale);
//     return '${_t(locale, {
//       'en': 'Please reply with 0, 1, 2, or 3 (or the option text).\n\n',
//       'zh': '请回复 0、1、2 或 3（或选项文本）。\n\n',
//     })}$options\n\n${_answerHint(locale)}';
//   }

//   String _itemText(_RunCache cache) {
//     final list = cache.scale == _Scale.phq9 ? _phq9Items : _gad7Items;
//     return list[cache.index];
//   }

//   String get _phq9Title => _t(locale, {
//         'en': 'PHQ-9 (last 2 weeks)',
//         'zh': 'PHQ-9（过去两周）',
//       });
//   String get _gad7Title => _t(locale, {
//         'en': 'GAD-7 (last 2 weeks)',
//         'zh': 'GAD-7（过去两周）',
//       });

//   String get _phq9Instruction => _t(locale, {
//         'en': 'Over the last 2 weeks, how often have you been bothered by the following problems?',
//         'zh': '在过去两周里，下列问题令你感到困扰的频率如何？',
//       });
//   String get _gad7Instruction => _phq9Instruction; // same framing window

//   String _optionText(String locale) {
//     return _t(locale, {
//       'en': '0) Not at all\n1) Several days\n2) More than half the days\n3) Nearly every day',
//       'zh': '0）完全没有\n1）好几天\n2）超过一半天数\n3）几乎每天',
//     });
//   }

//   String _answerHint(String locale) => _t(locale, {
//         'en': 'Tip: you can answer with 0/1/2/3 or the phrase (e.g., "Several days").',
//         'zh': '小提示：可直接回复 0/1/2/3 或对应短语（例如“好几天”）。',
//       });

//   String _buildResult(_RunCache cache, int total, _Severity severity) {
//     final title = cache.title;
//     final header = _t(locale, {
//       'en': '**$title** result',
//       'zh': '**$title** 结果',
//     });

//     final scoreLine = _t(locale, {
//       'en': 'Total score: $total  (range ${severity.range})',
//       'zh': '总分：$total（范围 ${severity.range}）',
//     });

//     final sevLine = _t(locale, {
//       'en': 'Severity: **${severity.labelEn}**',
//       'zh': '严重程度：**${severity.labelZh}**',
//     });

//     final note = _t(locale, {
//       'en': '\n\n*Note: This screening is not a diagnosis. If the score is moderate or above, consider consulting a clinician.*',
//       'zh': '\n\n*提示：本量表仅用于筛查，不能替代专业诊断。如得分达到中度或以上，建议咨询专业人士。*',
//     });

//     return '$header\n$scoreLine\n$sevLine$note';
//   }
// }

// // ====== Internals ======

// enum _Scale { phq9, gad7 }

// class _RunCache {
//   _RunCache({required this.scale})
//       : index = 0,
//         answers = <int>[];
//   final _Scale scale;
//   int index; // 0..N-1
//   final List<int> answers; // each 0..3
//   int get total => scale == _Scale.phq9 ? _phq9Items.length : _gad7Items.length;

//   String get title => scale == _Scale.phq9 ? _phq9Title : _gad7Title;
// }

// // Item banks (EN+ZH combined text lines)
// final List<String> _phq9Items = [
//   '1) $_phq9Instruction\n— Little interest or pleasure in doing things\n— 对做事情缺乏兴趣或乐趣',
//   '2) — Feeling down, depressed, or hopeless\n— 情绪低落、抑郁或绝望',
//   '3) — Trouble falling or staying asleep, or sleeping too much\n— 入睡困难、睡眠维持困难或睡得过多',
//   '4) — Feeling tired or having little energy\n— 感到疲倦或缺乏精力',
//   '5) — Poor appetite or overeating\n— 食欲不振或暴饮暴食',
//   '6) — Feeling bad about yourself — or that you are a failure or have let yourself or your family down\n— 觉得自己很糟、失败，或辜负自己/家人',
//   '7) — Trouble concentrating on things, such as reading the newspaper or watching television\n— 注意力难以集中（如读报或看电视时）',
//   '8) — Moving or speaking so slowly that other people could have noticed; or the opposite — being so fidgety or restless that you have been moving around a lot more than usual\n— 动作或说话变得迟缓、被他人察觉；或相反，坐立不安、比平时更为烦躁',
//   '9) — Thoughts that you would be better off dead or of hurting yourself in some way\n— 觉得死了会更好，或有以某种方式伤害自己的念头',
// ];

// final List<String> _gad7Items = [
//   '1) $_gad7Instruction\n— Feeling nervous, anxious, or on edge\n— 感到紧张、焦虑或烦躁',
//   '2) — Not being able to stop or control worrying\n— 无法停止或控制担忧',
//   '3) — Worrying too much about different things\n— 对各种事情过度担心',
//   '4) — Trouble relaxing\n— 难以放松',
//   '5) — Being so restless that it is hard to sit still\n— 烦躁到难以静坐',
//   '6) — Becoming easily annoyed or irritable\n— 容易生气或易怒',
//   '7) — Feeling afraid as if something awful might happen\n— 感到害怕，仿佛将要发生可怕的事情',
// ];

// // Titles + instructions use getters for locale inside cache.title
// const String _phq9Title = 'PHQ-9';
// const String _gad7Title = 'GAD-7';
// const String _phq9Instruction = 'Over the last 2 weeks';
// const String _gad7Instruction = 'Over the last 2 weeks';

// class _Severity {
//   const _Severity({required this.key, required this.range, required this.labelEn, required this.labelZh});
//   final String key; // e.g., minimal, mild, moderate, moderately_severe, severe
//   final String range; // e.g., 0-4, 5-9, ...
//   final String labelEn;
//   final String labelZh;
// }

// _Severity _phq9Severity(int score) {
//   if (score <= 4) return const _Severity(key: 'minimal', range: '0–4', labelEn: 'Minimal', labelZh: '最轻');
//   if (score <= 9) return const _Severity(key: 'mild', range: '5–9', labelEn: 'Mild', labelZh: '轻度');
//   if (score <= 14) return const _Severity(key: 'moderate', range: '10–14', labelEn: 'Moderate', labelZh: '中度');
//   if (score <= 19) return const _Severity(key: 'moderately_severe', range: '15–19', labelEn: 'Moderately severe', labelZh: '中重度');
//   return const _Severity(key: 'severe', range: '20–27', labelEn: 'Severe', labelZh: '重度');
// }

// _Severity _gad7Severity(int score) {
//   if (score <= 4) return const _Severity(key: 'minimal', range: '0–4', labelEn: 'Minimal', labelZh: '最轻');
//   if (score <= 9) return const _Severity(key: 'mild', range: '5–9', labelEn: 'Mild', labelZh: '轻度');
//   if (score <= 14) return const _Severity(key: 'moderate', range: '10–14', labelEn: 'Moderate', labelZh: '中度');
//   return const _Severity(key: 'severe', range: '15–21', labelEn: 'Severe', labelZh: '重度');
// }

// int? _parseAnswer(String raw) {
//   if (raw.isEmpty) return null;
//   final s = raw.trim().toLowerCase();
//   // direct numerics
//   final n = int.tryParse(s);
//   if (n != null && n >= 0 && n <= 3) return n;

//   // english keywords
//   if (s.contains('not at all')) return 0;
//   if (s.contains('several')) return 1; // several days
//   if (s.contains('more than half')) return 2;
//   if (s.contains('nearly') || s.contains('almost every') || s.contains('every day')) return 3;

//   // chinese keywords
//   if (s.contains('完全没有')) return 0;
//   if (s.contains('好几天')) return 1;
//   if (s.contains('超过一半') || s.contains('一半以上')) return 2;
//   if (s.contains('几乎每天')) return 3;

//   return null;
// }

// String _t(String locale, Map<String, String> byLang) {
//   if (locale.startsWith('zh')) return byLang['zh'] ?? byLang['en']!;
//   return byLang['en']!;
// }
