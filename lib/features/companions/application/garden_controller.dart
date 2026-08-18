import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_mhproj/core/providers/app_providers.dart';

class GardenState {
  const GardenState({
    required this.leaves,
    required this.plantGrowth,
    required this.unlockedPlants,
    required this.stickers,
    required this.activePlantId,
    required this.lastChallengeDate,
    this.isLoading = false,
  });

  final int leaves;
  final Map<String, int> plantGrowth;
  final List<String> unlockedPlants;
  final List<String> stickers;
  final String activePlantId;
  final DateTime? lastChallengeDate;
  final bool isLoading;

  GardenState copyWith({
    int? leaves,
    Map<String, int>? plantGrowth,
    List<String>? unlockedPlants,
    List<String>? stickers,
    String? activePlantId,
    DateTime? lastChallengeDate,
    bool? isLoading,
  }) {
    return GardenState(
      leaves: leaves ?? this.leaves,
      plantGrowth: plantGrowth ?? this.plantGrowth,
      unlockedPlants: unlockedPlants ?? this.unlockedPlants,
      stickers: stickers ?? this.stickers,
      activePlantId: activePlantId ?? this.activePlantId,
      lastChallengeDate: lastChallengeDate ?? this.lastChallengeDate,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  static GardenState initial() {
    return const GardenState(
      leaves: 0,
      plantGrowth: <String, int>{
        'lavender': 0,
        'fern': 0,
        'sunflower': 0,
        'bonsai': 0,
      },
      unlockedPlants: <String>['lavender'],
      stickers: <String>[],
      activePlantId: 'lavender',
      lastChallengeDate: null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'leaves': leaves,
      'plantGrowth': plantGrowth,
      'unlockedPlants': unlockedPlants,
      'stickers': stickers,
      'activePlantId': activePlantId,
      'lastChallengeDate': lastChallengeDate?.toIso8601String(),
    };
  }

  factory GardenState.fromJson(Map<String, dynamic> json) {
    return GardenState(
      leaves: json['leaves'] as int? ?? 0,
      plantGrowth: Map<String, int>.from(json['plantGrowth'] as Map? ?? {}),
      unlockedPlants: List<String>.from(
        json['unlockedPlants'] as List? ?? ['lavender'],
      ),
      stickers: List<String>.from(json['stickers'] as List? ?? []),
      activePlantId: json['activePlantId'] as String? ?? 'lavender',
      lastChallengeDate: json['lastChallengeDate'] != null
          ? DateTime.tryParse(json['lastChallengeDate'] as String)
          : null,
    );
  }
}

class GardenController extends StateNotifier<GardenState> {
  GardenController(this._prefs) : super(GardenState.initial()) {
    _load();
  }

  final SharedPreferences _prefs;
  static const String _storageKey = 'garden_state_v1';

  Future<void> _load() async {
    state = state.copyWith(isLoading: true);
    final String? raw = _prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final Map<String, dynamic> json =
            jsonDecode(raw) as Map<String, dynamic>;
        state = GardenState.fromJson(json).copyWith(isLoading: false);
      } catch (e) {
        debugPrint('Error loading garden state: $e');
        state = state.copyWith(isLoading: false);
      }
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _save() async {
    await _prefs.setString(_storageKey, jsonEncode(state.toJson()));
  }

  void addLeaves(int amount, {String? sticker}) {
    final List<String> newStickers = List<String>.from(state.stickers);
    if (sticker != null) {
      newStickers.insert(0, sticker);
    }
    state = state.copyWith(
      leaves: state.leaves + amount,
      stickers: newStickers,
    );
    _save();
    _checkUnlocks();
  }

  void addGrowth(int amount) {
    final Map<String, int> newGrowth = Map<String, int>.from(state.plantGrowth);
    final int current = newGrowth[state.activePlantId] ?? 0;
    newGrowth[state.activePlantId] = (current + amount).clamp(0, 999);
    state = state.copyWith(plantGrowth: newGrowth);
    _save();
  }

  void setActivePlant(String plantId) {
    if (state.unlockedPlants.contains(plantId)) {
      state = state.copyWith(activePlantId: plantId);
      _save();
    }
  }

  void completeChallenge() {
    state = state.copyWith(lastChallengeDate: DateTime.now());
    addLeaves(3, sticker: 'Gentle challenge complete');
    addGrowth(3);
  }

  bool get isChallengeCompleted {
    if (state.lastChallengeDate == null) return false;
    final DateTime now = DateTime.now();
    final DateTime last = state.lastChallengeDate!;
    return now.year == last.year &&
        now.month == last.month &&
        now.day == last.day;
  }

  void _checkUnlocks() {
    // Simple unlock logic: Unlock plants based on total leaves earned (or just current leaves for simplicity)
    // For now, let's say:
    // Fern: 10 leaves
    // Sunflower: 25 leaves
    // Bonsai: 50 leaves

    final List<String> unlocked = List<String>.from(state.unlockedPlants);
    bool changed = false;

    if (state.leaves >= 10 && !unlocked.contains('fern')) {
      unlocked.add('fern');
      changed = true;
    }
    if (state.leaves >= 25 && !unlocked.contains('sunflower')) {
      unlocked.add('sunflower');
      changed = true;
    }
    if (state.leaves >= 50 && !unlocked.contains('bonsai')) {
      unlocked.add('bonsai');
      changed = true;
    }

    if (changed) {
      state = state.copyWith(unlockedPlants: unlocked);
      _save();
    }
  }
}

final gardenControllerProvider =
    StateNotifierProvider<GardenController, GardenState>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return GardenController(prefs);
    });
