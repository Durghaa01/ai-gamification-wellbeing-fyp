import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../domain/appointment.dart';
import 'package:uuid/uuid.dart';

class AppointmentController extends StateNotifier<List<Appointment>> {
  AppointmentController(this._ref) : super(const []) {
    _init();
  }

  final Ref _ref;
  StreamSubscription<List<Appointment>>? _subscription;

  Future<void> _init() async {
    final userId = await _ref.read(currentUserIdProvider.future);
    if (userId == null) {
      state = const [];
      return;
    }

    final service = _ref.read(appointmentDataServiceProvider);
    _subscription = service.watchAppointments(userId).listen((appointments) {
      state = appointments;
    });
  }

  Future<void> add(Appointment appointment) async {
    state = [...state, appointment];

    final userId = await _ref.read(currentUserIdProvider.future);
    if (userId == null) {
      return;
    }

    final service = _ref.read(appointmentDataServiceProvider);
    final updated = appointment.copyWith(
      id: appointment.id ?? const Uuid().v4(),
      userId: userId,
    );
    await service.upsertAppointment(
      userId: userId,
      appointment: updated,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final appointmentControllerProvider =
    StateNotifierProvider<AppointmentController, List<Appointment>>(
      (ref) => AppointmentController(ref),
    );
