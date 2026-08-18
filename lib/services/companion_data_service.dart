import 'dart:async';

import '../features/companions/domain/companion_session.dart';
import '../models/assessment.dart';
import 'api/companion_remote_api.dart';
import 'local_data_store.dart';

/// Companion session data service with optional remote backend support.
class CompanionDataService {
  CompanionDataService({LocalDataStore? store, CompanionRemoteApi? remoteApi})
    : _store = store ?? LocalDataStore.instance,
      _remoteApi = remoteApi;

  final LocalDataStore _store;
  final CompanionRemoteApi? _remoteApi;
  final Map<String, StreamController<List<CompanionSessionSummary>>>
  _remoteControllers =
      <String, StreamController<List<CompanionSessionSummary>>>{};
  final Map<String, List<CompanionSessionSummary>> _remoteSnapshots =
      <String, List<CompanionSessionSummary>>{};

  bool get _useRemote => _remoteApi != null;

  Stream<List<CompanionSessionSummary>> watchSessions(
    String userId, {
    bool includeArchived = false,
  }) {
    if (!_useRemote) {
      return _store.watchCompanionSessions(
        userId,
        includeArchived: includeArchived,
      );
    }
    final controller = _remoteControllers.putIfAbsent(
      userId,
      () => StreamController<List<CompanionSessionSummary>>.broadcast(),
    );
    final cached = _remoteSnapshots[userId];
    if (cached != null) {
      controller.add(cached);
    }
    _refreshRemote(userId, includeArchived: true);
    return controller.stream.map((sessions) {
      if (includeArchived) {
        return sessions;
      }
      return sessions
          .where((session) => !session.isArchived)
          .toList(growable: false);
    });
  }

  Future<List<CompanionSessionSummary>> fetchSessions(
    String userId, {
    bool includeArchived = false,
  }) async {
    if (!_useRemote) {
      return _store.fetchCompanionSessions(
        userId,
        includeArchived: includeArchived,
      );
    }
    final sessions = await _remoteApi!.fetchSessions(
      userId,
      includeArchived: includeArchived,
    );
    _emitRemote(userId, sessions);
    return sessions;
  }

  Future<void> recordMessage({
    required String userId,
    required String sessionId,
    required String companionId,
    required String companionName,
    required AssessmentMessage message,
    String? sessionSummary,
  }) async {
    if (!_useRemote) {
      final sessions = await _store.fetchCompanionSessions(userId);
      final existing = sessions.firstWhere(
        (session) => session.id == sessionId,
        orElse: () => CompanionSessionSummary(
          id: sessionId,
          companionId: companionId,
          companionName: companionName,
          title: companionName,
          createdAt: message.ts,
          lastMessageAt: message.ts,
          messageCount: 0,
        ),
      );

      final messageTokens = _extractTokenCount(message);
      final latencyMs = (message.meta?['latencyMs'] as num?)?.toInt();
      final updated = CompanionSessionSummary(
        id: sessionId,
        companionId: companionId,
        companionName: companionName,
        title: existing.title ?? companionName,
        createdAt: existing.createdAt,
        lastMessageAt: message.ts,
        messageCount: existing.messageCount + 1,
        summary: sessionSummary ?? existing.summary,
        tokenCount: existing.tokenCount + messageTokens,
        latencyMs: latencyMs ?? existing.latencyMs,
        archivedAt: existing.archivedAt,
        isArchived: false,
      );

      _store.addCompanionMessage(userId: userId, session: updated);
      return;
    }

    final summary = await _remoteApi!.recordMessage(
      userId: userId,
      sessionId: sessionId,
      companionId: companionId,
      companionName: companionName,
      message: message,
      sessionSummary: sessionSummary,
    );
    await _refreshRemote(userId, optimistic: summary);
  }

  Future<List<AssessmentMessage>> fetchSessionMessages(
    String userId,
    String sessionId, {
    int limit = 50,
    DateTime? before,
    DateTime? after,
  }) async {
    if (!_useRemote) {
      return const <AssessmentMessage>[];
    }
    return _remoteApi!.fetchSessionMessages(
      userId,
      sessionId,
      limit: limit,
      before: before,
      after: after,
    );
  }

  Future<CompanionSessionSummary?> updateSession({
    required String userId,
    required String sessionId,
    String? title,
    bool? isArchived,
    String? summary,
    int? tokenCount,
    int? latencyMs,
  }) async {
    if (!_useRemote) {
      return _store.updateCompanionSession(
        userId: userId,
        sessionId: sessionId,
        title: title,
        isArchived: isArchived,
        summary: summary,
        tokenCount: tokenCount,
        latencyMs: latencyMs,
      );
    }
    final updated = await _remoteApi!.updateSession(
      userId: userId,
      sessionId: sessionId,
      title: title,
      isArchived: isArchived,
      summary: summary,
      tokenCount: tokenCount,
      latencyMs: latencyMs,
    );
    await _refreshRemote(userId);
    return updated;
  }

  Future<void> deleteSession({
    required String userId,
    required String sessionId,
  }) async {
    if (!_useRemote) {
      _store.deleteCompanionSession(userId: userId, sessionId: sessionId);
      return;
    }
    await _remoteApi!.deleteSession(userId, sessionId);
    _removeRemoteSnapshot(userId, sessionId);
    await _refreshRemote(userId);
  }

  Future<void> _refreshRemote(
    String userId, {
    CompanionSessionSummary? optimistic,
    bool includeArchived = true,
  }) async {
    try {
      if (optimistic != null && _remoteSnapshots.containsKey(userId)) {
        _mergeRemoteSnapshot(userId, optimistic);
        return;
      }
      final sessions = List<CompanionSessionSummary>.from(
        await _remoteApi!.fetchSessions(
          userId,
          includeArchived: includeArchived,
        ),
      );
      if (optimistic != null) {
        _mergeRemoteSnapshot(userId, optimistic, base: sessions);
      } else {
        _emitRemote(userId, sessions);
      }
    } catch (error) {
      final controller = _remoteControllers[userId];
      controller?.addError(error);
    }
  }

  void _emitRemote(String userId, List<CompanionSessionSummary> sessions) {
    final snapshot = List<CompanionSessionSummary>.unmodifiable(sessions);
    _remoteSnapshots[userId] = snapshot;
    final controller = _remoteControllers[userId];
    if (controller == null || controller.isClosed) {
      return;
    }
    controller.add(snapshot);
  }

  void _mergeRemoteSnapshot(
    String userId,
    CompanionSessionSummary summary, {
    List<CompanionSessionSummary>? base,
  }) {
    final working = List<CompanionSessionSummary>.from(
      base ?? _remoteSnapshots[userId] ?? const <CompanionSessionSummary>[],
    );
    final index = working.indexWhere((session) => session.id == summary.id);
    if (index >= 0) {
      working[index] = summary;
    } else {
      working.insert(0, summary);
    }
    _emitRemote(userId, working);
  }

  int _extractTokenCount(AssessmentMessage message) {
    final metaToken = (message.meta?['tokenCount'] as num?)?.toInt();
    if (metaToken != null) {
      return metaToken;
    }
    return (message.text.length / 4).ceil();
  }

  void _removeRemoteSnapshot(String userId, String sessionId) {
    final existing = _remoteSnapshots[userId];
    if (existing == null) {
      return;
    }
    final updated = existing
        .where((session) => session.id != sessionId)
        .toList();
    _emitRemote(userId, updated);
  }
}
