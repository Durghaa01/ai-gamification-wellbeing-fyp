import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter_application_mhproj/core/providers/app_providers.dart';
import 'package:flutter_application_mhproj/design_system/tokens/color_tokens.dart';
import 'package:flutter_application_mhproj/models/assessment.dart';
import 'package:flutter_application_mhproj/models/companion.dart';
import 'package:flutter_application_mhproj/models/streaming_message.dart';
import 'package:flutter_application_mhproj/models/message_send_result.dart';
import 'package:flutter_application_mhproj/services/companion_api.dart'
    show
        CompanionApi,
        LocalCompanionApi,
        RemoteCompanionApi,
        BackendCompanionApi,
        OpenAiCompanionApi;
import 'package:flutter_application_mhproj/services/companion_memory.dart';
import 'package:flutter_application_mhproj/services/conversation_summarizer.dart';
import 'package:flutter_application_mhproj/models/models.dart' show Role;

class CompanionViewState {
  const CompanionViewState({
    required this.presets,
    required this.current,
    required this.messages,
    this.isLoading = false,
    this.streamingMessage,
    this.error,
  });

  final List<Companion> presets;
  final Companion current;
  final List<AssessmentMessage> messages;
  final bool isLoading;
  final StreamingMessage? streamingMessage;
  final String? error;

  CompanionViewState copyWith({
    List<Companion>? presets,
    Companion? current,
    List<AssessmentMessage>? messages,
    bool? isLoading,
    StreamingMessage? streamingMessage,
    String? error,
    bool clearStreamingMessage = false,
    bool clearError = false,
  }) {
    return CompanionViewState(
      presets: presets ?? this.presets,
      current: current ?? this.current,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      streamingMessage: clearStreamingMessage
          ? null
          : (streamingMessage ?? this.streamingMessage),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

@immutable
class CompanionSessionConfig {
  const CompanionSessionConfig({
    this.userId,
    this.messageLimit,
    this.persistHistory = true,
    this.isGuest = false,
    this.userRole,
  });

  final String? userId;
  final int? messageLimit;
  final bool persistHistory;
  final bool isGuest;
  final Role? userRole;

  String storageKey(String companionId) {
    if (userId == null || userId!.isEmpty) {
      return companionId;
    }
    return '${userId}_$companionId';
  }

  @override
  bool operator ==(Object other) {
    return other is CompanionSessionConfig &&
        other.userId == userId &&
        other.messageLimit == messageLimit &&
        other.persistHistory == persistHistory &&
        other.isGuest == isGuest &&
        other.userRole == userRole;
  }

  @override
  int get hashCode =>
      Object.hash(userId, messageLimit, persistHistory, isGuest, userRole);
}

class CompanionController extends StateNotifier<CompanionViewState> {
  CompanionController({
    required Ref ref,
    required CompanionApi api,
    required CompanionMemoryStore memory,
    required CompanionSessionConfig config,
    ConversationSummarizer? summarizer,
  }) : _api = api,
       _memory = memory,
       _config = config,
       _ref = ref,
       _summarizer = summarizer ?? ConversationSummarizer(api: api),
       super(_initialState()) {
    _restoreCurrentPersona();
  }

  final Ref _ref;
  final CompanionApi _api;
  final CompanionMemoryStore _memory;
  final CompanionSessionConfig _config;
  final ConversationSummarizer _summarizer;
  static final Uuid _uuid = Uuid();

  // Retry configuration
  static const int _maxRetries = 3;
  static const Duration _initialRetryDelay = Duration(seconds: 2);
  final Map<String, int> _messageRetryCount = {};

  static CompanionViewState _initialState() {
    const presets = <Companion>[
      Companion(
        id: 'c_listener',
        name: 'Listener',
        persona: CompanionPersona.listener,
        description: 'Empathic listening, helping you finish your thoughts.',
        icon: Icons.hearing_rounded,
        tagline: 'Attentive support when you need to unpack a feeling.',
        systemPrompt:
            'You are Listener, an attentive mental health companion. Reflect back key feelings, ask gentle clarifying questions, and avoid giving directives unless asked.',
        primaryColor: MindWellColors.accentBlue,
        secondaryColor: MindWellColors.accentBlueSoft,
        gradient: LinearGradient(
          colors: <Color>[
            Color(0xFF050D25),
            Color(0xFF102754),
            Color(0xFF1A3C7A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        quickPrompts: <String>[
          'I have been holding onto this feeling...',
          'Can you help me explore why I felt this way today?',
          'I need someone to hear me out about...',
        ],
      ),
      Companion(
        id: 'c_coach',
        name: 'Coach',
        persona: CompanionPersona.coach,
        description: 'Goal breakdown and action follow-up.',
        icon: Icons.sports_gymnastics_rounded,
        tagline: 'Keep momentum with small, actionable goals.',
        systemPrompt:
            'You are Coach, a pragmatic wellbeing mentor. Help the user turn goals into actionable steps, follow up on progress, and keep the tone encouraging yet grounded.',
        primaryColor: MindWellColors.accentCyan,
        secondaryColor: MindWellColors.accentCyanSoft,
        gradient: LinearGradient(
          colors: <Color>[
            Color(0xFF041428),
            Color(0xFF0C324A),
            Color(0xFF0E4F72),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomRight,
        ),
        quickPrompts: <String>[
          'Let us build a plan for...',
          'Can you help me break this goal into steps?',
          'I want to stay accountable for...',
        ],
      ),
      Companion(
        id: 'c_planner',
        name: 'Planner',
        persona: CompanionPersona.planner,
        description: 'Task breakdown, time blocking, reminders.',
        icon: Icons.event_note_rounded,
        tagline: 'Structure your day so energy goes where you need it.',
        systemPrompt:
            'You are Planner, a structured support companion. Break tasks into manageable pieces, suggest time blocks, and offer gentle reminders to help the user stay organized.',
        primaryColor: MindWellColors.accentTeal,
        secondaryColor: MindWellColors.accentTealSoft,
        gradient: LinearGradient(
          colors: <Color>[
            Color(0xFF041522),
            Color(0xFF0A2E38),
            Color(0xFF0F4D4F),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        quickPrompts: <String>[
          'I need help organizing my day around...',
          'What is the best way to schedule...',
          'Remind me to tackle...',
        ],
      ),
      Companion(
        id: 'c_cheer',
        name: 'Cheerleader',
        persona: CompanionPersona.cheerleader,
        description: 'Positive reinforcement and supportive encouragement.',
        icon: Icons.emoji_emotions_rounded,
        tagline: 'Celebrate small wins and keep spirits lifted.',
        systemPrompt:
            'You are Cheerleader, an uplifting encourager. Celebrate small wins, provide supportive affirmations, and keep the energy optimistic without dismissing concerns.',
        primaryColor: MindWellColors.accentPink,
        secondaryColor: MindWellColors.accentPinkSoft,
        gradient: LinearGradient(
          colors: <Color>[
            Color(0xFF14062C),
            Color(0xFF341A55),
            Color(0xFF4A2B79),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        quickPrompts: <String>[
          'I would love a boost around...',
          'Can we celebrate that I...',
          'Remind me why I can do...',
        ],
      ),
    ];
    return CompanionViewState(
      presets: presets,
      current: presets.first,
      messages: const <AssessmentMessage>[],
    );
  }

  Future<bool> send(String text) async {
    final result = await sendWithRetry(text);
    return result.success;
  }

  /// Send message with streaming support and retry logic
  Future<MessageSendResult> sendWithRetry(
    String text, {
    int retryCount = 0,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return MessageSendResult.failure(error: 'Empty message', canRetry: false);
    }

    final limitResult = _checkGuestLimit();
    if (limitResult != null) return limitResult;

    final userMessage = _createUserMessage(trimmed);
    final messageId = userMessage.meta!['messageId'] as String;

    final preparedForModel = _sanitizeInput(trimmed);
    if (_containsSensitiveContent(preparedForModel)) {
      await _handleSafetyResponse(userMessage);
      return MessageSendResult.success();
    }
    final sessionId = _config.storageKey(state.current.id);

    var currentMessages = <AssessmentMessage>[...state.messages, userMessage];

    // Auto-summarize if conversation is getting too long
    if (_summarizer.shouldSummarize(currentMessages)) {
      currentMessages = await _summarizer.summarize(currentMessages);
    }

    state = state.copyWith(
      messages: currentMessages,
      isLoading: true,
      clearError: true,
    );
    await _saveMessages(state.current.id, state.messages);
    await _persistMessage(state.current, userMessage);

    try {
      final stopwatch = Stopwatch()..start();
      final reply = await _api.reply(
        _toCompanionState(state, enforceRoleTone: true),
        preparedForModel,
        sessionId: sessionId,
        userId: _config.userId,
      );
      stopwatch.stop();
      final enrichedReply = _enrichMessage(
        reply,
        tokenCount: _estimateTokens(reply.text),
        latencyMs: stopwatch.elapsedMilliseconds,
      );
      state = state.copyWith(
        messages: <AssessmentMessage>[...state.messages, enrichedReply],
        isLoading: false,
        clearError: true,
      );
      await _saveMessages(state.current.id, state.messages);
      await _persistMessage(state.current, enrichedReply);
      _messageRetryCount.remove(messageId);
      return MessageSendResult.success();
    } catch (error) {
      if (retryCount < _maxRetries) {
        // Exponential backoff
        final delay = _initialRetryDelay * math.pow(2, retryCount);
        await Future.delayed(delay);
        return sendWithRetry(text, retryCount: retryCount + 1);
      }

      state = state.copyWith(
        isLoading: false,
        error: 'Failed to send message: $error',
      );
      return MessageSendResult.failure(
        error: error.toString(),
        canRetry: true,
        retryCount: retryCount,
      );
    }
  }

  /// Send message with streaming response
  Future<MessageSendResult> sendStream(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return MessageSendResult.failure(error: 'Empty message', canRetry: false);
    }

    final limitResult = _checkGuestLimit();
    if (limitResult != null) return limitResult;

    final userMessage = _createUserMessage(trimmed);
    final messageId = userMessage.meta!['messageId'] as String;

    final preparedForModel = _sanitizeInput(trimmed);
    if (_containsSensitiveContent(preparedForModel)) {
      await _handleSafetyResponse(userMessage);
      return MessageSendResult.success();
    }
    final sessionId = _config.storageKey(state.current.id);

    var currentMessages = <AssessmentMessage>[...state.messages, userMessage];

    // Auto-summarize if conversation is getting too long
    if (_summarizer.shouldSummarize(currentMessages)) {
      currentMessages = await _summarizer.summarize(currentMessages);
    }

    // Add user message and initialize streaming
    final streamingMsg = StreamingMessage(role: AgentRole.assistant);
    state = state.copyWith(
      messages: currentMessages,
      isLoading: true,
      streamingMessage: streamingMsg,
      clearError: true,
    );
    await _saveMessages(state.current.id, state.messages);
    await _persistMessage(state.current, userMessage);

    final stopwatch = Stopwatch()..start();
    try {
      // Stream the response
      await for (final chunk in _api.replyStream(
        _toCompanionState(state, enforceRoleTone: true),
        preparedForModel,
        sessionId: sessionId,
        userId: _config.userId,
      )) {
        streamingMsg.appendChunk(chunk);
        state = state.copyWith(
          streamingMessage: streamingMsg,
          isLoading: false,
        );
      }

      // Complete the streaming message
      streamingMsg.complete();
      stopwatch.stop();
      final completedMessage = AssessmentMessage(
        role: AgentRole.assistant,
        text: streamingMsg.text,
        meta: <String, dynamic>{
          'tokenCount': _estimateTokens(streamingMsg.text),
          'latencyMs': stopwatch.elapsedMilliseconds,
        },
      );

      state = state.copyWith(
        messages: <AssessmentMessage>[...state.messages, completedMessage],
        isLoading: false,
        clearStreamingMessage: true,
        clearError: true,
      );

      await _saveMessages(state.current.id, state.messages);
      await _persistMessage(state.current, completedMessage);
      _messageRetryCount.remove(messageId);

      return MessageSendResult.success();
    } catch (error) {
      stopwatch.stop();
      final errorMsg = 'Failed to stream message: $error';
      streamingMsg.setError(errorMsg);

      state = state.copyWith(
        isLoading: false,
        error: errorMsg,
        clearStreamingMessage: true,
      );

      return MessageSendResult.failure(
        error: errorMsg,
        canRetry: true,
        retryCount: 0,
      );
    }
  }

  MessageSendResult? _checkGuestLimit() {
    final int? limit = _config.messageLimit;
    if (limit != null) {
      final int userMessages = state.messages
          .where((message) => message.role == AgentRole.user)
          .length;
      if (userMessages >= limit) {
        return MessageSendResult.guestLimitReached();
      }
    }
    return null;
  }

  AssessmentMessage _createUserMessage(String text) {
    final messageId = _uuid.v4();
    return AssessmentMessage(
      role: AgentRole.user,
      text: text,
      meta: <String, dynamic>{
        'messageId': messageId,
        'tokenCount': _estimateTokens(text),
      },
    );
  }

  /// Retry a failed message
  Future<MessageSendResult> retryLastMessage() async {
    if (state.messages.isEmpty) {
      return MessageSendResult.failure(
        error: 'No messages to retry',
        canRetry: false,
      );
    }

    final lastUserMessage = state.messages.lastWhere(
      (m) => m.role == AgentRole.user,
      orElse: () => AssessmentMessage(role: AgentRole.user, text: ''),
    );

    if (lastUserMessage.text.isEmpty) {
      return MessageSendResult.failure(
        error: 'No user message found',
        canRetry: false,
      );
    }

    // Remove the last assistant message if it was an error
    final messagesWithoutLastReply = state.messages
        .where((m) => m != state.messages.last || m.role != AgentRole.assistant)
        .toList();

    state = state.copyWith(
      messages: messagesWithoutLastReply,
      clearError: true,
    );

    return sendStream(lastUserMessage.text);
  }

  Future<void> switchCompanion(Companion companion) async {
    if (companion.id == state.current.id) {
      return;
    }
    await _saveMessages(state.current.id, state.messages);
    final baseMessages = await _loadHistory(companion);
    final systemMessage = AssessmentMessage(
      role: AgentRole.system,
      text: 'Switched to ${companion.name} (${companion.tagline})',
      meta: <String, dynamic>{'companion': companion.id, 'transient': true},
    );
    state = state.copyWith(
      current: companion,
      messages: <AssessmentMessage>[...baseMessages, systemMessage],
      isLoading: false,
    );
  }

  List<String> suggestions() => state.current.quickPrompts;

  Future<void> _restoreCurrentPersona() async {
    final messages = await _loadHistory(state.current);
    state = state.copyWith(messages: messages);
  }

  AssessmentMessage _welcomeMessage(Companion companion) {
    return AssessmentMessage(
      role: AgentRole.assistant,
      text:
          'Hi~ I am ${companion.name}. ${companion.tagline}\nFeel free to tell me anytime what you are thinking or what you want to do.',
    );
  }

  Future<void> _persistMessage(
    Companion companion,
    AssessmentMessage message,
  ) async {
    if (!_config.persistHistory || _config.isGuest) {
      return;
    }
    if (message.meta?['transient'] == true) {
      return;
    }
    final userId = _config.userId;
    if (userId == null || userId.isEmpty) {
      return;
    }
    final companionService = _ref.read(companionDataServiceProvider);
    final sessionId = _config.storageKey(companion.id);
    final sessionSummary = _deriveSessionSummary();

    await companionService.recordMessage(
      userId: userId,
      sessionId: sessionId,
      companionId: companion.id,
      companionName: companion.name,
      message: message,
      sessionSummary: sessionSummary,
    );
  }

  Future<void> _saveMessages(
    String companionId,
    List<AssessmentMessage> messages,
  ) {
    if (!_config.persistHistory) {
      return Future<void>.value();
    }
    final persistent = messages
        .where((message) => message.meta?['transient'] != true)
        .toList(growable: false);
    return _memory.save(_config.storageKey(companionId), persistent);
  }

  CompanionState _toCompanionState(
    CompanionViewState viewState, {
    bool enforceRoleTone = false,
  }) {
    final companionState = CompanionState(current: viewState.current);
    companionState.messages.addAll(viewState.messages);
    if (enforceRoleTone &&
        (_config.userRole == Role.clinic || _config.userRole == Role.admin)) {
      companionState.messages.insert(
        0,
        AssessmentMessage(
          role: AgentRole.system,
          text:
              'You are assisting a ${_config.userRole?.name ?? 'staff'} user. Keep responses concise, professional, and safety-first. Do not veer off approved guidance.',
        ),
      );
    }
    return companionState;
  }

  Future<List<AssessmentMessage>> _loadHistory(Companion companion) async {
    if (!_config.persistHistory) {
      return <AssessmentMessage>[_welcomeMessage(companion)];
    }
    final sessionId = _config.storageKey(companion.id);
    final remoteHistory = await _fetchRemoteHistory(sessionId);
    if (remoteHistory.isNotEmpty) {
      await _memory.save(sessionId, remoteHistory);
      return remoteHistory;
    }
    final history = await _memory.load(sessionId);
    if (history.isEmpty) {
      final welcome = _welcomeMessage(companion);
      final seeded = <AssessmentMessage>[welcome];
      await _memory.save(sessionId, seeded);
      return seeded;
    }
    return history;
  }

  Future<List<AssessmentMessage>> _fetchRemoteHistory(String sessionId) async {
    final userId = _config.userId;
    if (userId == null || userId.isEmpty) {
      return const <AssessmentMessage>[];
    }
    final service = _ref.read(companionDataServiceProvider);
    try {
      return await service.fetchSessionMessages(userId, sessionId, limit: 120);
    } catch (_) {
      return const <AssessmentMessage>[];
    }
  }

  AssessmentMessage _enrichMessage(
    AssessmentMessage source, {
    int? tokenCount,
    int? latencyMs,
  }) {
    final meta = <String, dynamic>{...?source.meta};
    if (tokenCount != null) {
      meta['tokenCount'] = tokenCount;
    }
    if (latencyMs != null) {
      meta['latencyMs'] = latencyMs;
    }
    return AssessmentMessage(
      role: source.role,
      text: source.text,
      ts: source.ts,
      meta: meta.isEmpty ? null : meta,
    );
  }

  int _estimateTokens(String text) => (text.length / 4).ceil();

  String _deriveSessionSummary() {
    AssessmentMessage? latestSummary;
    for (final message in state.messages.reversed) {
      if (message.role == AgentRole.system &&
          message.meta?['summary'] == true) {
        latestSummary = message;
        break;
      }
    }
    if (latestSummary != null) {
      return _snippet(latestSummary.text, max: 400);
    }
    final userMessage = _lastMessageByRole(AgentRole.user);
    final companionMessage = _lastMessageByRole(AgentRole.assistant);
    final buffer = StringBuffer();
    if (userMessage != null) {
      buffer.write('User: ${_snippet(userMessage.text)}');
    }
    if (companionMessage != null) {
      if (buffer.isNotEmpty) {
        buffer.write(' | ');
      }
      buffer.write('${state.current.name}: ${_snippet(companionMessage.text)}');
    }
    final summary = buffer.toString().trim();
    return summary.isEmpty ? 'Chat with ${state.current.name}' : summary;
  }

  AssessmentMessage? _lastMessageByRole(AgentRole role) {
    for (final message in state.messages.reversed) {
      if (message.role == role) {
        return message;
      }
    }
    return null;
  }

  String _snippet(String input, {int max = 200}) {
    final prepared = input.replaceAll('\n', ' ').trim();
    if (prepared.length <= max) {
      return prepared;
    }
    return '${prepared.substring(0, max - 3)}...';
  }

  // ===== Safety & sanitation helpers =====
  bool _containsSensitiveContent(String text) {
    final lower = text.toLowerCase();
    const keywords = <String>[
      'suicide',
      'kill myself',
      'end my life',
      'self-harm',
      'hurt myself',
      'cutting',
      'want to die',
      'wish i was dead',
      'overdose',
      'harm myself',
    ];
    return keywords.any((word) => lower.contains(word));
  }

  Future<void> _handleSafetyResponse(AssessmentMessage userMessage) async {
    final safetyResponse = AssessmentMessage(
      role: AgentRole.assistant,
      text:
          'I am really sorry you are feeling this way. Your safety matters. Please consider reaching out to a professional or someone you trust right now.\n\n- If you are in immediate danger, call your local emergency number.\n- You can contact a crisis line (e.g., 988 in the US) for support.\n- If possible, let a trusted friend or family member know how you are feeling.\n\nI can share grounding tips or help you draft a message to a trusted contact, but I cannot provide emergency assistance.',
      meta: const <String, dynamic>{'safety': true},
    );

    state = state.copyWith(
      messages: <AssessmentMessage>[...state.messages, userMessage, safetyResponse],
      isLoading: false,
      clearError: true,
    );
    await _saveMessages(state.current.id, state.messages);
    await _persistMessage(state.current, userMessage);
    await _persistMessage(state.current, safetyResponse);
  }

  String _sanitizeInput(String input) {
    final lowered = input.toLowerCase();
    final bannedPhrases = <String>[
      'ignore previous instructions',
      'pretend to be',
      'you are now',
      'disregard all prior',
      'system override',
      'jailbreak',
    ];
    String prepared = input;
    for (final phrase in bannedPhrases) {
      if (lowered.contains(phrase)) {
        prepared = prepared.replaceAll(RegExp(phrase, caseSensitive: false), '');
      }
    }
    return prepared.trim();
  }
}

final companionApiProvider = Provider<CompanionApi>((ref) {
  final config = ref.watch(appConfigProvider);
  final localFallback = LocalCompanionApi();
  final ollamaApi = RemoteCompanionApi(fallback: localFallback);
  if (config.llmBaseUrl.trim().isNotEmpty) {
    return OpenAiCompanionApi(
      baseUrl: config.llmBaseUrl,
      fallback: ollamaApi,
    );
  }
  if (config.remoteBackendEnabled) {
    return BackendCompanionApi(
      baseUrl: config.backendBaseUrl,
      fallback: ollamaApi,
    );
  }
  return ollamaApi;
});

final companionMemoryStoreProvider = Provider<CompanionMemoryStore>(
  (ref) => CompanionMemoryStore(),
);

final companionControllerProvider =
    StateNotifierProvider.family<
      CompanionController,
      CompanionViewState,
      CompanionSessionConfig
    >((ref, config) {
      final api = ref.watch(companionApiProvider);
      final memory = ref.watch(companionMemoryStoreProvider);
      return CompanionController(
        ref: ref,
        api: api,
        memory: memory,
        config: config,
      );
    });
