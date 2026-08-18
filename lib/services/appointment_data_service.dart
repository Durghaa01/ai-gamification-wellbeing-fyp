import '../features/appointments/domain/appointment.dart';
import 'local_data_store.dart';

class AppointmentDataService {
  AppointmentDataService({LocalDataStore? store})
      : _store = store ?? LocalDataStore.instance;

  final LocalDataStore _store;

  Stream<List<Appointment>> watchAppointments(String userId) {
    return _store.watchAppointments(userId);
  }

  Future<List<Appointment>> fetchAppointments(String userId) {
    return _store.fetchAppointments(userId);
  }

  Future<void> upsertAppointment({
    required String userId,
    required Appointment appointment,
  }) async {
    await _store.upsertAppointment(
      userId: userId,
      appointmentId: appointment.id ?? '',
      appointment: appointment,
    );
  }

  Future<void> deleteAppointment({
    required String userId,
    required String appointmentId,
  }) async {
    await _store.deleteAppointment(
      userId: userId,
      appointmentId: appointmentId,
    );
  }
}
