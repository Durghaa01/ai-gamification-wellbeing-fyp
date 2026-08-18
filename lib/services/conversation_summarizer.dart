import '../models/assessment.dart';
import 'companion_api.dart';

/// Service for summarizing long conversations to manage context window
class ConversationSummarizer {
  ConversationSummarizer({
    required CompanionApi api,
    this.maxMessages = 50,
    this.summaryThreshold = 30,
  }) : _api = api;

  final CompanionApi _api;
  final int maxMessages;
  final int summaryThreshold;

  /// Check if summarization is needed
  bool shouldSummarize(List<AssessmentMessage> messages) {
    final conversationMessages = messages
        .where((m) => m.role != AgentRole.system || m.meta?['summary'] != true)
        .toList();
    return conversationMessages.length >= summaryThreshold;
  }

  /// Summarize older messages while keeping recent ones
  Future<List<AssessmentMessage>> summarize(
    List<AssessmentMessage> messages,
  ) async {
    if (!shouldSummarize(messages)) {
      return messages;
    }

    // Separate system messages (summaries) from conversation
    final systemMessages = messages
        .where((m) => m.role == AgentRole.system && m.meta?['summary'] == true)
        .toList();
    
    final conversationMessages = messages
        .where((m) => m.role != AgentRole.system || m.meta?['summary'] != true)
        .toList();

    if (conversationMessages.length < summaryThreshold) {
      return messages;
    }

    // Keep recent messages, summarize older ones
    final messagesToKeep = conversationMessages.length - summaryThreshold;
    final recentMessages = conversationMessages.sublist(messagesToKeep);
    final oldMessages = conversationMessages.sublist(0, messagesToKeep);

    // Generate summary of old messages
    final summaryText = await _generateSummary(oldMessages);

    final summaryMessage = AssessmentMessage(
      role: AgentRole.system,
      text: 'Previous conversation summary: $summaryText',
      ts: oldMessages.last.ts,
      meta: <String, dynamic>{
        'summary': true,
        'message_count': oldMessages.length,
      },
    );

    // Return: existing summaries + new summary + recent messages
    return <AssessmentMessage>[
      ...systemMessages,
      summaryMessage,
      ...recentMessages,
    ];
  }

  /// Generate a summary using simple heuristics or AI
  Future<String> _generateSummary(List<AssessmentMessage> messages) async {
    // For now, use simple extraction-based summarization
    // In production, this could call an LLM for better summaries
    
    if (messages.isEmpty) {
      return 'No previous messages.';
    }

    final buffer = StringBuffer();
    
    // Extract key topics from user messages
    final userMessages = messages
        .where((m) => m.role == AgentRole.user)
        .toList();
    
    if (userMessages.isEmpty) {
      return 'Previous assistant responses.';
    }

    // Get first and last user messages as context
    final firstMessage = userMessages.first.text;
    final lastMessage = userMessages.last.text;

    if (userMessages.length <= 2) {
      buffer.write('User discussed: $firstMessage');
    } else {
      buffer.write('User initially mentioned: ${_extractKeyPhrase(firstMessage)}. ');
      buffer.write('Later discussed: ${_extractKeyPhrase(lastMessage)}. ');
      buffer.write('Total: ${messages.length} messages exchanged.');
    }

    return buffer.toString();
  }

  /// Extract key phrase from a message (simple implementation)
  String _extractKeyPhrase(String text) {
    // Take first 100 characters or first sentence
    final truncated = text.length > 100
        ? '${text.substring(0, 97)}...'
        : text;
    
    final firstSentence = truncated.split(RegExp(r'[.!?]')).first;
    return firstSentence.trim();
  }

  /// Estimate token count for messages (rough approximation)
  int estimateTokens(List<AssessmentMessage> messages) {
    return messages.fold(
      0,
      (sum, msg) => sum + (msg.text.length ~/ 4), // ~4 chars per token
    );
  }

  /// Trim messages to fit within a token budget
  List<AssessmentMessage> trimToTokenBudget(
    List<AssessmentMessage> messages, {
    int maxTokens = 4000,
  }) {
    if (estimateTokens(messages) <= maxTokens) {
      return messages;
    }

    // Keep system messages and most recent messages
    final systemMessages = messages
        .where((m) => m.role == AgentRole.system)
        .toList();
    
    final conversationMessages = messages
        .where((m) => m.role != AgentRole.system)
        .toList();

    var result = <AssessmentMessage>[...systemMessages];
    var tokens = estimateTokens(systemMessages);

    // Add recent messages until we hit the budget
    for (final message in conversationMessages.reversed) {
      final messageTokens = message.text.length ~/ 4;
      if (tokens + messageTokens > maxTokens) {
        break;
      }
      result.insert(systemMessages.length, message);
      tokens += messageTokens;
    }

    return result;
  }
}
