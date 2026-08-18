import '../domain/appointment.dart';
import 'package:flutter/material.dart';

class MockAppointmentRepository {
  // In-memory storage for mock data
  static final List<Appointment> _mockAppointments = [];
  
  // Mock counselor data
  static final Map<String, String> _mockCounselors = {
    'counselor-1': 'Dr. Sarah Johnson',
    'counselor-2': 'Dr. Michael Chen',
    'counselor-3': 'Dr. Emily Rodriguez',
  };

  /// Get all appointments for a specific user
  Future<List<Appointment>> getAppointmentsByUserId(String userId) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    return _mockAppointments
        .where((apt) => apt.userId == userId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // Most recent first
  }

  /// Get all appointments for a specific counselor
  Future<List<Appointment>> getAppointmentsByCounselorId(String counselorId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    return _mockAppointments
        .where((apt) => apt.counselorId == counselorId)
        .toList();
  }

  /// Get a single appointment by ID
  Future<Appointment?> getAppointmentById(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    try {
      return _mockAppointments.firstWhere((apt) => apt.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Create a new appointment
  Future<void> createAppointment(Appointment appointment) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _mockAppointments.add(appointment);
    print('✅ Mock: Created appointment ${appointment.id}');
  }

  /// Update an existing appointment
  Future<void> updateAppointment(Appointment appointment) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    final index = _mockAppointments.indexWhere((apt) => apt.id == appointment.id);
    if (index != -1) {
      _mockAppointments[index] = appointment;
      print('✅ Mock: Updated appointment ${appointment.id}');
    }
  }

  /// Delete an appointment
  Future<void> deleteAppointment(String id) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _mockAppointments.removeWhere((apt) => apt.id == id);
    print('✅ Mock: Deleted appointment $id');
  }

  /// Get counselor name by ID
  String getCounselorName(String counselorId) {
    return _mockCounselors[counselorId] ?? 'Unknown Counselor';
  }

  /// Get all available counselors
  Map<String, String> getAllCounselors() {
    return Map.from(_mockCounselors);
  }

  /// Clear all mock data (useful for testing)
  void clearAllData() {
    _mockAppointments.clear();
    print('🗑️ Mock: Cleared all appointments');
  }

  /// Seed some test data (call this to test returning user flow)
  void seedTestData(String userId) {
    _mockAppointments.add(
      Appointment(
        userId: userId,
        counselorId: 'counselor-1',
        date: DateTime.now().subtract(const Duration(days: 30)),
        time: const TimeOfDay(hour: 14, minute: 0),
        mode: 'Video Call',
        medication: 'Sertraline 50mg',
        remark: 'Patient showing improvement',
      ),
    );
    
    _mockAppointments.add(
      Appointment(
        userId: userId,
        counselorId: 'counselor-1',
        date: DateTime.now().subtract(const Duration(days: 7)),
        time: const TimeOfDay(hour: 15, minute: 30),
        mode: 'In-Person',
        medication: 'Sertraline 50mg',
        remark: 'Continued progress',
      ),
    );
    
    print('🌱 Mock: Seeded test data for user $userId');
  }
}