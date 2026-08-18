import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_mhproj/features/companions/application/companion_controller.dart';
import 'package:flutter_application_mhproj/features/companions/domain/companion_session.dart';
import 'package:flutter_application_mhproj/models/assessment.dart';
import 'package:flutter_application_mhproj/models/companion.dart';
import 'package:flutter_application_mhproj/models/message_send_result.dart';
import 'package:flutter_application_mhproj/services/companion_api.dart';
import 'package:flutter_application_mhproj/services/companion_memory.dart';
import 'package:flutter_application_mhproj/services/conversation_summarizer.dart';

// Fakes
class FakeCompanionApi implements CompanionApi {
  AssessmentMessage? nextReply;
  List<String>? nextStreamChunks;
  Object? error;

  @override
  Future<AssessmentMessage> reply(
    CompanionState state,
    String userInput, {
    String? sessionId,
    String? userId,
  }) async {
    if (error != null) throw error!;
    return nextReply ??
        AssessmentMessage(
          role: AgentRole.assistant,
          text: 'Echo: $userInput',
          meta: {},
        );
  }

  @override
  Stream<String> replyStream(
    CompanionState state,
    String userInput, {
    String? sessionId,
    String? userId,
  }) async* {
    if (error != null) throw error!;
    if (nextStreamChunks != null) {
      for (final chunk in nextStreamChunks!) {
        yield chunk;
      }
    } else {
      yield 'Echo: ';
      yield userInput;
    }
  }
}

class FakeCompanionMemoryStore implements CompanionMemoryStore {
  final Map<String, List<AssessmentMessage>> _storage = {};

  @override
  Future<void> save(
    String companionId,
    List<AssessmentMessage> messages,
  ) async {
    _storage[companionId] = messages;
  }

  @override
  Future<List<AssessmentMessage>> load(String companionId) async {
    return _storage[companionId] ?? [];
  }

  @override
  Future<void> clear(String companionId) async {
    _storage.remove(companionId);
  }
}

class FakeConversationSummarizer implements ConversationSummarizer {
  bool shouldSummarizeResult = false;

  @override
  final int maxMessages = 50;

  @override
  final int summaryThreshold = 30;

  @override
  bool shouldSummarize(List<AssessmentMessage> messages) =>
      shouldSummarizeResult;

  @override
  Future<List<AssessmentMessage>> summarize(
    List<AssessmentMessage> messages,
  ) async {
    return messages; // No-op for test
  }

  @override
  int estimateTokens(List<AssessmentMessage> messages) {
    return messages.fold(0, (sum, msg) => sum + (msg.text.length ~/ 4));
  }

  @override
  List<AssessmentMessage> trimToTokenBudget(
    List<AssessmentMessage> messages, {
    int maxTokens = 4000,
  }) {
    return messages;
  }
}

void main() {
  late FakeCompanionApi api;
  late FakeCompanionMemoryStore memory;
  late FakeConversationSummarizer summarizer;
  late ProviderContainer container;
  late CompanionSessionConfig config;

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() {
    api = FakeCompanionApi();
    memory = FakeCompanionMemoryStore();
    summarizer = FakeConversationSummarizer();
    config = const CompanionSessionConfig(
      userId: 'test-user',
      persistHistory: false,
      messageLimit: null,
      isGuest: false,
    );

    container = ProviderContainer(
      overrides: [
        companionApiProvider.overrideWithValue(api),
        companionMemoryStoreProvider.overrideWithValue(memory),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  Future<CompanionController> _buildController(
    CompanionSessionConfig cfg,
  ) async {
    final controller = container.read(
      companionControllerProvider(cfg).notifier,
    );
    // Allow async init (_restoreCurrentPersona) to complete
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return controller;
  }

  group('CompanionController', () {
    test('initial state is correct', () async {
      final controller = await _buildController(config);
      expect(controller.state.messages.isEmpty, false);
      expect(controller.state.error, isNull);
    });

    test('sendWithRetry success', () async {
      final controller = await _buildController(config);
      final result = await controller.sendWithRetry('Hello');
      if (!result.success) {
        // Debug aid to surface failure details
        // ignore: avoid_print
        print('sendWithRetry failed: error=${result.error} state=${controller.state.error}');
      }

      expect(
        result.success,
        true,
        reason:
            'expected success, got error=${result.error}, stateError=${controller.state.error}',
      );
      expect(controller.state.messages.length, greaterThanOrEqualTo(2));
      expect(controller.state.messages.any((m) => m.text == 'Hello'), true);
      expect(controller.state.messages.last.text, 'Echo: Hello');
      expect(controller.state.isLoading, false);
    });

    test('sendWithRetry fails on empty message', () async {
      final controller = container.read(
        companionControllerProvider(config).notifier,
      );
      final result = await controller.sendWithRetry('');

      expect(result.success, false);
      expect(result.error, 'Empty message');
    });

    test('sendWithRetry handles guest limit', () async {
      final guestConfig = const CompanionSessionConfig(
        userId: 'guest',
        persistHistory: false,
        messageLimit: 1,
        isGuest: true,
      );
      final guestContainer = ProviderContainer(
        overrides: [
          companionApiProvider.overrideWithValue(api),
          companionMemoryStoreProvider.overrideWithValue(memory),
        ],
      );
      final controller = guestContainer.read(
        companionControllerProvider(guestConfig).notifier,
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));

      // First message should succeed
      var result = await controller.sendWithRetry('First');
      expect(result.success, true,
          reason: 'first send failed: ${result.error}');
      final userCount = controller.state.messages
          .where((m) => m.role == AgentRole.user)
          .length;
      expect(userCount, greaterThanOrEqualTo(1));

      // Second message fails with guest limit
      result = await controller.sendWithRetry('Second');
      expect(
        result.success,
        false,
        reason:
            'guest limit not enforced, userCount=${controller.state.messages.where((m) => m.role == AgentRole.user).length}',
      );
      expect(result.error, 'Guest message limit reached');

      guestContainer.dispose();
    });

    test('sendWithRetry handles API error', () async {
      final controller = container.read(
        companionControllerProvider(config).notifier,
      );
      api.error = Exception('API Error');

      final result = await controller.sendWithRetry('Hello');

      expect(result.success, false);
      expect(result.error, contains('API Error'));
      expect(controller.state.error, contains('API Error'));
      expect(controller.state.isLoading, false);
    });

    test('sendStream success', () async {
      final controller = container.read(
        companionControllerProvider(config).notifier,
      );
      api.nextStreamChunks = ['Hel', 'lo'];

      final result = await controller.sendStream('Hi');

      expect(result.success, true);
      expect(
        controller.state.messages.length,
        greaterThanOrEqualTo(2),
      ); // Welcome + User + Assistant
      expect(controller.state.messages.last.text, 'Hello');
      expect(controller.state.isLoading, false);
    });

    test('sendStream handles API error', () async {
      final controller = container.read(
        companionControllerProvider(config).notifier,
      );
      api.error = Exception('Stream Error');

      final result = await controller.sendStream('Hi');

      expect(result.success, false);
      expect(controller.state.error, contains('Stream Error'));
      expect(controller.state.isLoading, false);
    });
  });
}
