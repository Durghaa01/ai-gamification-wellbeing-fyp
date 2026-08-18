import '../models/models.dart';
import 'local_data_store.dart';

/// Provides typed accessors over the local user store.
class UserDataService {
  UserDataService({LocalDataStore? store})
      : _store = store ?? LocalDataStore.instance;

  final LocalDataStore _store;

  Future<AppUser?> fetchUser(String userId) async {
    return _store.fetchUser(userId);
  }

  Stream<AppUser?> watchUser(String userId) {
    return _store.watchUser(userId);
  }

  Stream<List<AppUser>> watchUsers() {
    return _store.watchUsers();
  }

  Future<void> deleteUser(String userId) async {
    _store.deleteUser(userId);
  }

  Future<void> upsertUser(AppUser user) async {
    _store.upsertUser(user);
  }
}
