import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// Centralised in-memory repository that replaces the static [DemoStore].
///
/// The current app still works with mock data, but moving the data access
/// behind this abstraction makes it easier to swap in a real backend later
/// without touching every page.
class MindWellRepository extends ChangeNotifier {
  MindWellRepository._();

  static final MindWellRepository instance = MindWellRepository._();

  bool _seeded = false;
  final List<AppUser> _users = [];
  final List<Clinic> _clinics = [];

  List<AppUser> get users => List.unmodifiable(_users);
  List<Clinic> get clinics => List.unmodifiable(_clinics);

  void seed() {
    if (_seeded) return;
    _users.addAll([
      AppUser(
        id: 'u1',
        name: 'Alice Tan',
        email: 'alice@example.com',
        role: Role.user,
        age: 28,
        gender: 'F',
      ),
      AppUser(
        id: 'u2',
        name: 'Ben Wong',
        email: 'ben@example.com',
        role: Role.user,
        age: 35,
        gender: 'M',
      ),
      AppUser(
        id: 'u3',
        name: 'W',
        email: 'w@example.com',
        role: Role.user,
        age: 26,
        gender: 'M',
      ),
    ]);
    _clinics.addAll([
      Clinic(
        id: 'c1',
        name: 'Harmony Clinic',
        address: '123 Wellness Ave',
        patients: [_users[0], _users[1]],
      ),
      Clinic(
        id: 'c2',
        name: 'Sunrise Medical',
        address: '88 Care Street',
        patients: [_users[2]],
      ),
    ]);
    _seeded = true;
    notifyListeners();
  }

  Clinic? findClinicById(String id) {
    try {
      return _clinics.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  AppUser? findUserByEmail(String email) {
    final lower = email.toLowerCase();
    try {
      return _users.firstWhere((u) => u.email.toLowerCase() == lower);
    } catch (_) {
      return null;
    }
  }

  AppUser createUser(String name, String email, {Role role = Role.user}) {
    final user = AppUser(
      id: 'u${_users.length + 1}',
      name: name,
      email: email,
      role: role,
    );
    _users.add(user);
    notifyListeners();
    return user;
  }

  void saveUserNotes(AppUser user, String notes) {
    user.notes = notes;
    notifyListeners();
  }

  void removeUser(AppUser user) {
    _users.remove(user);
    for (final clinic in _clinics) {
      clinic.patients.removeWhere((p) => p.id == user.id);
    }
    notifyListeners();
  }

  void addPatientToClinic(Clinic clinic, AppUser user) {
    if (!clinic.patients.any((p) => p.id == user.id)) {
      clinic.patients.add(user);
      notifyListeners();
    }
  }

  void removePatientFromClinic(Clinic clinic, AppUser user) {
    clinic.patients.removeWhere((p) => p.id == user.id);
    notifyListeners();
  }

  Clinic createClinic({required String name, String? address}) {
    final clinic = Clinic(
      id: 'c${_clinics.length + 1}',
      name: name,
      address: address,
    );
    _clinics.add(clinic);
    notifyListeners();
    return clinic;
  }

  void removeClinic(Clinic clinic) {
    _clinics.removeWhere((c) => c.id == clinic.id);
    notifyListeners();
  }
}
