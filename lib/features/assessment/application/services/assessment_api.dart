import 'dart:async';
import '../../domain/models/assessment.dart';
import 'questionnaire_service.dart';

abstract class AssessmentApi {
  Future<AssessmentMessage> reply(AssessmentState state, String userInput);
}

/// 规则占位：可离线跑的 CBT/ACT 提示流，便于 UI 联调与单测
class LocalRuleApi implements AssessmentApi {
  @override
  Future<AssessmentMessage> reply(AssessmentState state, String userInput) async {
    // 模拟生成时间
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final mode = state.mode;

    String next;
    switch (mode) {
      case AssessmentMode.cbt:
        next = _cbtStep(state, userInput);
        break;
      case AssessmentMode.act:
        next = _actStep(state, userInput);
        break;
      case AssessmentMode.phq9:
        // TODO: Handle this case.
        throw UnimplementedError();
      case AssessmentMode.gad7:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
    return AssessmentMessage(role: AgentRole.assistant, text: next, meta: {'stage': state.stage});
  }

  String _cbtStep(AssessmentState s, String user) {
    // 非严格 CBT，仅作为占位流程：问题 -> 自动思维 -> 证据 -> 重评估
    switch (s.stage) {
      case 0:
        s.stage++;
        return "Thank you for sharing. CBT will start with**specific situation**.\n"
               "👉 Can you describe the most recent situation that troubled you? (What happened, when and where it happened, and who was involved)";
      case 1:
        s.stage++;
        return "What thoughts came to your mind at that moment**Automatic thoughts**(Thoughts / images / predictions)？\n"
               "You can list 1–3 in short sentences.";
      case 2:
        s.stage++;
        return "Let’s examine the evidence:\n"
               "• What evidence supports these thoughts?\n"
               "• What evidence contradicts these thoughts or offers an alternative explanation?？";
      default:
        // 之后循环在重评估&行为尝试
        return "Based on the above review, try to come up with a**more balanced new thought**，And give it a **belief rating** from 0–100%.。\n"
               "If you’re willing, we can design a small **behavioral experiment** to test it.";
    }
  }

  String _actStep(AssessmentState s, String user) {
    // ACT 占位流程：觉察 → 价值澄清 → 承诺行动
    switch (s.stage) {
      case 0:
        s.stage++;
        return "Let’s start with **present-moment awareness**: What sensations do you notice in your body right now? What thoughts are passing through your mind? No need to change anything—just notice them.";
      case 1:
        s.stage++;
        return "Let’s talk about the **values you care about**: In relationships, work, health, or personal growth, what matters most to you right now?\n"
               "You can describe it in 1–2 sentences.";
      default:
        return "Based on your **values**, choose a small, doable action (something you can complete within this week, in under 15 minutes).\n"
               "Example: Send a message to someone important, take a 10-minute walk, or start writing 5 lines in your journal.";
    }
  }
}

/// 预留：对接远端/本地大模型（Transformer）
/// - 可以把 state.messages 序列化为 prompt，发送到你的 API
/// - 也可改为 SSE/流式
class RemoteAssessmentApi implements AssessmentApi {
  RemoteAssessmentApi({required this.endpoint, this.apiKey});
  final String endpoint;
  final String? apiKey;

  @override
  Future<AssessmentMessage> reply(AssessmentState state, String userInput) async {
    // TODO: 实现 HTTP 调用，示例：
    // final payload = {
    //   'mode': state.mode.name,
    //   'messages': state.messages.map((m)=>{'role': m.role.name, 'text': m.text}).toList(),
    //   'user_input': userInput,
    // };
    // final res = await http.post(Uri.parse(endpoint), headers: {...}, body: jsonEncode(payload));
    // final text = jsonDecode(res.body)['text'] as String;
    // return AssessmentMessage(role: AgentRole.assistant, text: text);
    throw UnimplementedError('Implement your transformer endpoint here.');
  }
}

Object createApi(AssessmentMode mode) {
  switch (mode) {
    case AssessmentMode.cbt:
    case AssessmentMode.act:
      return LocalRuleApi();                 // 你已有
    case AssessmentMode.phq9:
    case AssessmentMode.gad7:
      return QuestionnaireApi(locale: 'en'); // 或 'en'
  }
}
