import "../infrastructure/mock_appointment_repository.dart";
import "../domain/appointment.dart";

// lib/application/appointment_service.dart
class AppointmentService {
  final MockAppointmentRepository _repository;

  AppointmentService(this._repository);

  /// Check if user is booking their first appointment
  Future<bool> isFirstTimeUser(String userId) async {
    final appointments = await _repository.getAppointmentsByUserId(userId);
    final isFirstTime = appointments.isEmpty;
    print('🔍 Checking if user $userId is first-time: $isFirstTime');
    return isFirstTime;
  }

  /// Get the counselor ID from user's most recent appointment
  Future<String?> getAssignedCounselorId(String userId) async {
    final appointments = await _repository.getAppointmentsByUserId(userId);
    
    if (appointments.isEmpty) {
      print('🔍 No counselor assigned for user $userId');
      return null;
    }
    
    final counselorId = appointments.first.counselorId;
    print('🔍 Assigned counselor for user $userId: $counselorId');
    return counselorId;
  }

  /// Get all appointments for a user
  Future<List<Appointment>> getAppointmentHistory(String userId) async {
    return await _repository.getAppointmentsByUserId(userId);
  }

  /// Book a new appointment
  Future<void> bookAppointment(Appointment appointment) async {
    await _repository.createAppointment(appointment);
  }

  /// Update existing appointment
  Future<void> updateAppointment(Appointment appointment) async {
    await _repository.updateAppointment(appointment);
  }

  /// Cancel appointment
  Future<void> cancelAppointment(String appointmentId) async {
    await _repository.deleteAppointment(appointmentId);
  }

  /// Get counselor name
  String getCounselorName(String counselorId) {
    return _repository.getCounselorName(counselorId);
  }

  /// Get all available counselors
  Map<String, String> getAllCounselors() {
    return _repository.getAllCounselors();
  }
}
