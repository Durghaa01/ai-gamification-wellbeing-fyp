import 'dart:async';

import '../features/journal/domain/journal_models.dart';
import 'api/journal_remote_api.dart';
import 'local_data_store.dart';

/// Journal data provider capable of hitting the remote FastAPI backend or the
/// seeded in-memory store depending on configuration.
class JournalDataService {
  JournalDataService({LocalDataStore? store, JournalRemoteApi? remoteApi})
    : _store = store ?? LocalDataStore.instance,
      _remoteApi = remoteApi;

  final LocalDataStore _store;
  final JournalRemoteApi? _remoteApi;
  final Map<String, StreamController<List<JournalEntry>>> _remoteControllers =
      <String, StreamController<List<JournalEntry>>>{};

  bool get _useRemote => _remoteApi != null;

  Stream<List<JournalEntry>> watchEntries(String userId) {
    if (!_useRemote) {
      return _store.watchJournalEntries(userId);
    }
    final controller = _remoteControllers.putIfAbsent(
      userId,
      () => StreamController<List<JournalEntry>>.broadcast(),
    );
    _refreshRemote(userId);
    return controller.stream;
  }

  Future<List<JournalEntry>> fetchEntries(String userId) async {
    if (!_useRemote) {
      return _store.fetchJournalEntries(userId);
    }
    final entries = await _remoteApi!.fetchEntries(userId);
    _emitRemote(userId, entries);
    return entries;
  }

  Future<void> upsertEntry({
    required String userId,
    required JournalEntry entry,
  }) async {
    if (!_useRemote) {
      _store.saveJournalEntry(userId, entry);
      return;
    }
    await _remoteApi!.upsertEntry(
      userId: userId,
      mood: entry.mood,
      tags: entry.tags,
      note: entry.note,
      entryDate: entry.createdAt,
    );
    await _refreshRemote(userId);
  }

  Future<void> _refreshRemote(String userId) async {
    try {
      final entries = await _remoteApi!.fetchEntries(userId);
      _emitRemote(userId, entries);
    } catch (error) {
      final controller = _remoteControllers[userId];
      controller?.addError(error);
    }
  }

  void _emitRemote(String userId, List<JournalEntry> entries) {
    final controller = _remoteControllers[userId];
    if (controller == null || controller.isClosed) {
      return;
    }
    controller.add(List<JournalEntry>.unmodifiable(entries));
  }
}
