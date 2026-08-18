// lib/application/appointment_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../infrastructure/mock_appointment_repository.dart';
import './appointment_service.dart';
import '../domain/appointment.dart';

// Provider for repository (singleton)
final mockAppointmentRepositoryProvider = Provider<MockAppointmentRepository>((ref) {
  return MockAppointmentRepository();
});

// Provider for service
final appointmentServiceProvider = Provider<AppointmentService>((ref) {
  final repository = ref.watch(mockAppointmentRepositoryProvider);
  return AppointmentService(repository);
});

// Provider to check if user is first-time
final isFirstTimeUserProvider = FutureProvider.family<bool, String>((ref, userId) async {
  final service = ref.watch(appointmentServiceProvider);
  return await service.isFirstTimeUser(userId);
});

// Provider to get assigned counselor ID
final assignedCounselorIdProvider = FutureProvider.family<String?, String>((ref, userId) async {
  final service = ref.watch(appointmentServiceProvider);
  return await service.getAssignedCounselorId(userId);
});

// Provider to get assigned counselor name
final assignedCounselorNameProvider = FutureProvider.family<String?, String>((ref, userId) async {
  final service = ref.watch(appointmentServiceProvider);
  final counselorId = await service.getAssignedCounselorId(userId);
  
  if (counselorId == null) return null;
  return service.getCounselorName(counselorId);
});

// Provider to get appointment history
final appointmentHistoryProvider = FutureProvider.family<List<Appointment>, String>((ref, userId) async {
  final service = ref.watch(appointmentServiceProvider);
  return await service.getAppointmentHistory(userId);
});

// Provider to get all counselors
final allCounselorsProvider = Provider<Map<String, String>>((ref) {
  final service = ref.watch(appointmentServiceProvider);
  return service.getAllCounselors();
});