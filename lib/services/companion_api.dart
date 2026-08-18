import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/assessment.dart';
import '../models/companion.dart';

/// Abstract API for companion interactions
abstract class CompanionApi {
  /// Send a message and get a complete response
  Future<AssessmentMessage> reply(
    CompanionState state,
    String userInput, {
    String? sessionId,
    String? userId,
  });
  
  /// Send a message and get a streaming response (for real-time rendering)
  Stream<String> replyStream(
    CompanionState state,
    String userInput, {
    String? sessionId,
    String? userId,
  });
}

/// Local fallback API (rule-based responses)
class LocalCompanionApi implements CompanionApi {
  @override
  Future<AssessmentMessage> reply(
    CompanionState state,
    String userInput, {
    String? sessionId,
    String? userId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 480));
    final text = _generate(state, userInput);
    return AssessmentMessage(role: AgentRole.assistant, text: text);
  }

  @override
  Stream<String> replyStream(
    CompanionState state,
    String userInput, {
    String? sessionId,
    String? userId,
  }) async* {
    // Simulate streaming by yielding complete response after delay
    await Future<void>.delayed(const Duration(milliseconds: 480));
    final text = _generate(state, userInput);
    yield text;
  }

  String _generate(CompanionState state, String user) {
    final companion = state.current;
    final lastUser = _lastUserMessage(state.messages);
    final prefix = lastUser == null ? '' : 'Earlier you shared "$lastUser". ';

    switch (companion.persona) {
      case CompanionPersona.listener:
        final reflection =
            '${prefix}I am hearing how much "$user" is sitting with you right now.';
        const invitation =
            'What part of this would feel most helpful to explore together?';
        return '$reflection\n\n$invitation';
      case CompanionPersona.coach:
        final framing =
            '${prefix}Let us turn "$user" into a plan you can follow.';
        const steps =
            '1. Name the specific outcome you want.\n'
            '2. Identify the friction that keeps it from moving.\n'
            '3. Choose one action you can take in the next 24 hours.';
        return '$framing\n\n$steps\n\nWhich step feels like the right place to start?';
      case CompanionPersona.planner:
        final framing =
            '${prefix}Here is a lightweight schedule we can try for "$user":';
        const steps =
            '- Clarify the deliverable in one sentence.\n'
            '- Reserve a 25 minute focus block.\n'
            '- Decide the first five minute action to get moving.';
        return '$framing\n$steps\n\nWant me to turn that into calendar friendly wording?';
      case CompanionPersona.cheerleader:
        final framing =
            '${prefix}I am proud of how you are showing up for "$user".';
        const encouragement =
            'Take a breath and notice one thing you did well, no matter how small.';
        return '$framing\n\n$encouragement\n\nWhat is a tiny way you can celebrate yourself today?';
    }
  }

  String? _lastUserMessage(List<AssessmentMessage> messages) {
    for (final message in messages.reversed) {
      if (message.role == AgentRole.user) {
        return message.text;
      }
    }
    return null;
  }
}

/// 远端/本地 Transformer（调用 Ollama）
class RemoteCompanionApi implements CompanionApi {
  RemoteCompanionApi({
    String? endpoint,
    this.apiKey,
    http.Client? client,
    CompanionApi? fallback,
    String model = _defaultModel,
  }) : _endpoint = endpoint ?? _resolveOllamaEndpoint(),
       _model = model,
       _client = client ?? http.Client(),
       _fallback = fallback;

  static const String _defaultModel = 'gpt-oss:20b';

  final String _endpoint;
  final String? apiKey;
  final String _model;
  final http.Client _client;
  final CompanionApi? _fallback;

  @override
  Future<AssessmentMessage> reply(
    CompanionState state,
    String userInput, {
    String? sessionId,
    String? userId,
  }) async {
    final prompt = _buildPrompt(state.current, state.messages);
    final uri = Uri.parse(_endpoint);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (apiKey != null && apiKey!.isNotEmpty)
        'Authorization': 'Bearer $apiKey',
    };
    final body = jsonEncode(<String, dynamic>{
      'model': _model,
      'prompt': prompt,
      'stream': false,
    });

    try {
      final response = await _client.post(uri, headers: headers, body: body);
      if (response.statusCode != 200) {
        throw RemoteCompanionException(
          'Ollama responded with status ${response.statusCode}',
          details: response.body,
        );
      }

      final Map<String, dynamic> payload =
          jsonDecode(response.body) as Map<String, dynamic>;
      final String reply = (payload['response'] as String?)?.trim() ?? '';
      if (reply.isEmpty) {
        throw const RemoteCompanionException(
          'Received empty response from Ollama.',
        );
      }

      return AssessmentMessage(role: AgentRole.assistant, text: reply);
    } catch (error) {
      return await _handleFailure(state, userInput, error);
    }
  }

  @override
  Stream<String> replyStream(
    CompanionState state,
    String userInput, {
    String? sessionId,
    String? userId,
  }) async* {
    final prompt = _buildPrompt(state.current, state.messages);
    final uri = Uri.parse(_endpoint);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (apiKey != null && apiKey!.isNotEmpty)
        'Authorization': 'Bearer $apiKey',
    };
    final body = jsonEncode(<String, dynamic>{
      'model': _model,
      'prompt': prompt,
      'stream': true, // Enable streaming
    });

    try {
      final request = http.Request('POST', uri);
      request.headers.addAll(headers);
      request.body = body;

      final streamedResponse = await _client.send(request);
      
      if (streamedResponse.statusCode != 200) {
        // Fall back to non-streaming on error
        final message = await reply(state, userInput);
        yield message.text;
        return;
      }

      // Parse streaming JSON responses
      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        final lines = chunk.split('\n').where((l) => l.trim().isNotEmpty);
        for (final line in lines) {
          try {
            final json = jsonDecode(line) as Map<String, dynamic>;
            final response = json['response'] as String?;
            if (response != null && response.isNotEmpty) {
              yield response;
            }
            // Check if stream is done
            if (json['done'] == true) {
              return;
            }
          } catch (_) {
            // Skip malformed JSON lines
            continue;
          }
        }
      }
    } catch (error) {
      // Fall back to non-streaming on error
      if (_fallback != null) {
        yield* _fallback!.replyStream(state, userInput);
      } else {
        final message = _buildErrorMessage(error);
        yield message.text;
      }
    }
  }

  AssessmentMessage _buildErrorMessage(Object error) {
    return AssessmentMessage(
      role: AgentRole.assistant,
      text:
          'I ran into a connection issue when calling $_endpoint:\n$error\nPlease confirm the Ollama server is running on your machine and reachable from this device.',
    );
  }

  Future<AssessmentMessage> _handleFailure(
    CompanionState state,
    String userInput,
    Object error,
  ) async {
    if (_fallback != null) {
      try {
        return await _fallback!.reply(state, userInput);
      } catch (_) {
        // If fallback also fails, fall through to error message.
      }
    }
    return _buildErrorMessage(error);
  }

  static String _resolveOllamaEndpoint() {
    if (kIsWeb) {
      return 'http://127.0.0.1:11434/api/generate';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android emulators map host machine localhost to 10.0.2.2.
      return 'http://10.0.2.2:11434/api/generate';
    }
    // For iOS simulator and desktop builds, localhost points to the host machine.
    return 'http://127.0.0.1:11434/api/generate';
  }

  String _buildPrompt(Companion companion, List<AssessmentMessage> history) {
    final buffer = StringBuffer()
      ..writeln(companion.systemPrompt)
      ..writeln('\nConversation:');

    for (final message in history) {
      final String speaker = switch (message.role) {
        AgentRole.user => 'User',
        AgentRole.assistant => companion.name,
        AgentRole.system => 'System',
      };
      buffer.writeln('$speaker: ${message.text}');
    }

    buffer
      ..writeln(
        '\nRespond in the voice of the ${companion.name.toLowerCase()} persona. Keep a warm, supportive tone.',
      )
      ..writeln(
        'Offer a concise answer and end with an open invitation to continue.',
      );
    return buffer.toString();
  }
}

class RemoteCompanionException implements Exception {
  const RemoteCompanionException(this.message, {this.details});

  final String message;
  final String? details;

  @override
  String toString() {
    if (details == null || details!.isEmpty) {
      return message;
    }
    return '$message\n$details';
  }
}

/// OpenAI-compatible API (llama.cpp server).
class OpenAiCompanionApi implements CompanionApi {
  OpenAiCompanionApi({
    required String baseUrl,
    String model = _defaultModel,
    double temperature = 0.8,
    double topP = 0.9,
    int maxTokens = 320,
    String? apiKey,
    http.Client? client,
    CompanionApi? fallback,
  }) : _baseUri = _normalizeBase(baseUrl),
       _model = model,
       _temperature = temperature,
       _topP = topP,
       _maxTokens = maxTokens,
       _apiKey = apiKey,
       _client = client ?? http.Client(),
       _fallback = fallback;

  static const String _defaultModel = 'local';

  final Uri _baseUri;
  final String _model;
  final double _temperature;
  final double _topP;
  final int _maxTokens;
  final String? _apiKey;
  final http.Client _client;
  final CompanionApi? _fallback;

  static Uri _normalizeBase(String value) {
    final trimmed = value.trim().replaceAll(RegExp(r'/+$'), '');
    return Uri.parse(trimmed.isEmpty ? 'http://127.0.0.1:8000' : trimmed);
  }

  Uri _buildUri(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final basePath = _baseUri.path;
    final mergedPath =
        basePath.endsWith('/v1') && normalizedPath.startsWith('/v1')
            ? '$basePath${normalizedPath.substring(3)}'
            : '$basePath$normalizedPath';
    return _baseUri.replace(path: mergedPath);
  }

  @override
  Future<AssessmentMessage> reply(
    CompanionState state,
    String userInput, {
    String? sessionId,
    String? userId,
  }) async {
    final payload = <String, dynamic>{
      'model': _model,
      'messages': _buildMessages(state.current, state.messages),
      'temperature': _temperature,
      'top_p': _topP,
      'max_tokens': _maxTokens,
      'stream': false,
    };
    try {
      final response = await _client.post(
        _buildUri('/v1/chat/completions'),
        headers: _buildHeaders(),
        body: jsonEncode(payload),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> json =
            jsonDecode(response.body) as Map<String, dynamic>;
        final text = _extractContent(json);
        if (text != null && text.trim().isNotEmpty) {
          return AssessmentMessage(role: AgentRole.assistant, text: text.trim());
        }
      }
      throw RemoteCompanionException(
        'OpenAI endpoint responded with status ${response.statusCode}',
        details: response.body,
      );
    } catch (error) {
      return _handleFailure(state, userInput, error);
    }
  }

  @override
  Stream<String> replyStream(
    CompanionState state,
    String userInput, {
    String? sessionId,
    String? userId,
  }) async* {
    final payload = <String, dynamic>{
      'model': _model,
      'messages': _buildMessages(state.current, state.messages),
      'temperature': _temperature,
      'top_p': _topP,
      'max_tokens': _maxTokens,
      'stream': true,
    };
    try {
      final request = http.Request(
        'POST',
        _buildUri('/v1/chat/completions'),
      );
      request.headers.addAll(_buildHeaders());
      request.body = jsonEncode(payload);
      final streamed = await _client.send(request);
      if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
        await for (final chunk in streamed.stream.transform(utf8.decoder)) {
          for (final line in chunk.split('\n')) {
            final trimmed = line.trim();
            if (trimmed.isEmpty) continue;
            if (!trimmed.startsWith('data:')) {
              continue;
            }
            final data = trimmed.replaceFirst('data:', '').trim();
            if (data == '[DONE]') {
              return;
            }
            final content = _extractContentFromStream(data);
            if (content != null && content.isNotEmpty) {
              yield content;
            }
          }
        }
        return;
      }
      final message = await reply(state, userInput);
      yield message.text;
    } catch (error) {
      if (_fallback != null) {
        yield* _fallback!.replyStream(state, userInput);
      } else {
        yield _buildErrorMessage(error).text;
      }
    }
  }

  List<Map<String, String>> _buildMessages(
    Companion companion,
    List<AssessmentMessage> history,
  ) {
    final messages = <Map<String, String>>[
      <String, String>{
        'role': 'system',
        'content': _buildSystemPrompt(companion),
      },
    ];
    for (final message in history) {
      if (message.meta?['transient'] == true) {
        continue;
      }
      final role = switch (message.role) {
        AgentRole.user => 'user',
        AgentRole.assistant => 'assistant',
        AgentRole.system => 'system',
      };
      messages.add(<String, String>{'role': role, 'content': message.text});
    }
    return messages;
  }

  String _buildSystemPrompt(Companion companion) {
    return [
      companion.systemPrompt,
      'Respond in the voice of the ${companion.name.toLowerCase()} persona.',
      'Keep a warm, supportive tone.',
      'Offer a concise answer and end with an open invitation to continue.',
    ].join('\n');
  }

  String? _extractContent(Map<String, dynamic> json) {
    final choices = json['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map<String, dynamic>) {
        final message = first['message'];
        if (message is Map<String, dynamic>) {
          return message['content'] as String?;
        }
        return first['text'] as String?;
      }
    }
    return null;
  }

  String? _extractContentFromStream(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final choices = json['choices'];
      if (choices is List && choices.isNotEmpty) {
        final first = choices.first;
        if (first is Map<String, dynamic>) {
          final delta = first['delta'];
          if (delta is Map<String, dynamic>) {
            return delta['content'] as String?;
          }
          final message = first['message'];
          if (message is Map<String, dynamic>) {
            return message['content'] as String?;
          }
          return first['text'] as String?;
        }
      }
    } catch (_) {
      // Ignore malformed JSON chunks.
    }
    return null;
  }

  AssessmentMessage _buildErrorMessage(Object error) {
    return AssessmentMessage(
      role: AgentRole.assistant,
      text:
          'I ran into a connection issue when calling $_baseUri:\n$error\nPlease confirm the LLM endpoint is reachable.',
    );
  }

  Future<AssessmentMessage> _handleFailure(
    CompanionState state,
    String userInput,
    Object error,
  ) async {
    if (_fallback != null) {
      try {
        return await _fallback!.reply(state, userInput);
      } catch (_) {
        // fall through to error message
      }
    }
    return _buildErrorMessage(error);
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_apiKey != null && _apiKey!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_apiKey';
    }
    return headers;
  }
}

/// Backend-hosted companion API (FastAPI bridge with streaming support).
class BackendCompanionApi implements CompanionApi {
  BackendCompanionApi({
    required String baseUrl,
    CompanionApi? fallback,
    http.Client? client,
  })  : _baseUri = _normalizeBase(baseUrl),
        _client = client ?? http.Client(),
        _fallback = fallback;

  final Uri _baseUri;
  final http.Client _client;
  final CompanionApi? _fallback;

  static Uri _normalizeBase(String value) {
    final trimmed = value.trim().replaceAll(RegExp(r'/+$'), '');
    return Uri.parse(trimmed.isEmpty ? 'http://127.0.0.1:8000' : trimmed);
  }

  Uri _buildUri(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return _baseUri.replace(path: '${_baseUri.path}$normalizedPath');
  }

  @override
  Future<AssessmentMessage> reply(
    CompanionState state,
    String userInput, {
    String? sessionId,
    String? userId,
  }) async {
    final payload = <String, dynamic>{
      'session_id': sessionId ?? 'local-${state.current.id}',
      'user_id': userId,
      'companion_id': state.current.id,
      'companion_name': state.current.name,
      'message': userInput,
      'stream': false,
    };
    final headers = _buildHeaders(userId: userId, json: true);
    try {
      final response = await _client.post(
        _buildUri('/api/v1/companions/chat-completions'),
        headers: headers,
        body: jsonEncode(payload),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> json =
            jsonDecode(response.body) as Map<String, dynamic>;
        final text = (json['response'] as String?)?.trim();
        if (text != null && text.isNotEmpty) {
          return AssessmentMessage(role: AgentRole.assistant, text: text);
        }
      }
      throw RemoteCompanionException(
        'Backend companion responded with status ${response.statusCode}',
        details: response.body,
      );
    } catch (error) {
      return _handleFailure(state, userInput, error);
    }
  }

  @override
  Stream<String> replyStream(
    CompanionState state,
    String userInput, {
    String? sessionId,
    String? userId,
  }) async* {
    final payload = <String, dynamic>{
      'session_id': sessionId ?? 'local-${state.current.id}',
      'user_id': userId,
      'companion_id': state.current.id,
      'companion_name': state.current.name,
      'message': userInput,
      'stream': true,
    };
    final headers = _buildHeaders(userId: userId, json: true);

    try {
      final request = http.Request(
        'POST',
        _buildUri('/api/v1/companions/chat-completions'),
      );
      request.headers.addAll(headers);
      request.body = jsonEncode(payload);
      final streamed = await _client.send(request);
      if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
        await for (final chunk in streamed.stream.transform(utf8.decoder)) {
          for (final line in chunk.split('\n')) {
            final trimmed = line.trim();
            if (trimmed.isEmpty) continue;
            if (trimmed.startsWith('data:')) {
              final data = trimmed.replaceFirst('data:', '').trim();
              if (data == '[DONE]') {
                return;
              }
              yield data;
            } else {
              yield trimmed;
            }
          }
        }
        return;
      }
      // Fall back to non-streaming if not 2xx
      final message = await reply(
        state,
        userInput,
        sessionId: sessionId,
        userId: userId,
      );
      yield message.text;
    } catch (error) {
      if (_fallback != null) {
        yield* _fallback!.replyStream(
          state,
          userInput,
          sessionId: sessionId,
          userId: userId,
        );
      } else {
        yield _buildErrorMessage(error).text;
      }
    }
  }

  Future<AssessmentMessage> _handleFailure(
    CompanionState state,
    String userInput,
    Object error,
  ) async {
    if (_fallback != null) {
      try {
        return await _fallback!.reply(
          state,
          userInput,
          sessionId: null,
          userId: null,
        );
      } catch (_) {
        // fall through to error message
      }
    }
    return _buildErrorMessage(error);
  }

  AssessmentMessage _buildErrorMessage(Object error) {
    return AssessmentMessage(
      role: AgentRole.assistant,
      text:
          'I had trouble reaching the companion service: $error\nPlease retry in a moment.',
    );
  }

  Map<String, String> _buildHeaders({
    String? userId,
    bool json = false,
  }) {
    final headers = <String, String>{};
    if (json) {
      headers['Content-Type'] = 'application/json';
    }
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final token = session?.accessToken;
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {
      // Supabase not initialized; skip auth header
    }
    if (userId != null && userId.isNotEmpty) {
      headers['X-User-Id'] = userId;
    }
    return headers;
  }
}
