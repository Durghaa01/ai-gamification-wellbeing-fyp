// lib/infrastructure/mock_availability_repository.dart

import 'package:flutter/material.dart';
import '../domain/time_slot.dart';

class MockAvailabilityRepository {
  // Mock: Define working hours for counselors
  static const Map<String, Map<String, dynamic>> _counselorSchedules = {
    'counselor-1': {
      'workingDays': [1, 2, 3, 4, 5], // Monday to Friday
      'startHour': 9,
      'endHour': 17,
      'slotDuration': 60, // minutes
    },
    'counselor-2': {
      'workingDays': [1, 2, 3, 4, 5, 6], // Monday to Saturday
      'startHour': 10,
      'endHour': 18,
      'slotDuration': 60,
    },
    'counselor-3': {
      'workingDays': [2, 3, 4, 5, 6], // Tuesday to Saturday
      'startHour': 8,
      'endHour': 16,
      'slotDuration': 60,
    },
  };

  // Mock booked appointments
  static final Map<String, List<Map<String, dynamic>>> _bookedSlots = {
    'counselor-1': [
      {
        'date': DateTime(2024, 12, 15),
        'time': const TimeOfDay(hour: 10, minute: 0),
      },
      {
        'date': DateTime(2024, 12, 15),
        'time': const TimeOfDay(hour: 14, minute: 0),
      },
    ],
  };

  /// Get available time slots for a counselor on a specific date
  Future<List<TimeSlot>> getAvailableSlots(
    String counselorId,
    DateTime date,
  ) async {
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate API call

    final schedule = _counselorSchedules[counselorId];
    if (schedule == null) {
      return []; // Counselor not found
    }

    final workingDays = schedule['workingDays'] as List<int>;
    final startHour = schedule['startHour'] as int;
    final endHour = schedule['endHour'] as int;
    final slotDuration = schedule['slotDuration'] as int;

    // Check if counselor works on this day (1 = Monday, 7 = Sunday)
    final dayOfWeek = date.weekday;
    if (!workingDays.contains(dayOfWeek)) {
      return []; // Counselor doesn't work on this day
    }

    // Check if date is in the past
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(date.year, date.month, date.day);
    
    if (selectedDate.isBefore(today)) {
      return []; // Can't book in the past
    }

    // Generate time slots
    final slots = <TimeSlot>[];
    for (int hour = startHour; hour < endHour; hour++) {
      final time = TimeOfDay(hour: hour, minute: 0);
      
      // Check if this slot is already booked
      final isBooked = _isSlotBooked(counselorId, date, time);
      
      // Check if slot is in the past (for today)
      bool isPast = false;
      if (selectedDate.isAtSameMomentAs(today)) {
        final currentTime = TimeOfDay.now();
        isPast = _isTimeBefore(time, currentTime);
      }

      slots.add(TimeSlot(
        time: time,
        isAvailable: !isBooked && !isPast,
        reason: isBooked 
            ? 'Already booked' 
            : isPast 
                ? 'Past time' 
                : null,
      ));
    }

    return slots;
  }

  /// Check if a specific slot is booked
  bool _isSlotBooked(String counselorId, DateTime date, TimeOfDay time) {
    final bookedSlots = _bookedSlots[counselorId] ?? [];
    
    return bookedSlots.any((slot) {
      final bookedDate = slot['date'] as DateTime;
      final bookedTime = slot['time'] as TimeOfDay;
      
      return bookedDate.year == date.year &&
          bookedDate.month == date.month &&
          bookedDate.day == date.day &&
          bookedTime.hour == time.hour &&
          bookedTime.minute == time.minute;
    });
  }

  /// Check if time1 is before time2
  bool _isTimeBefore(TimeOfDay time1, TimeOfDay time2) {
    if (time1.hour < time2.hour) return true;
    if (time1.hour > time2.hour) return false;
    return time1.minute < time2.minute;
  }

  /// Check if counselor is available on a specific date (has any slots)
  Future<bool> isCounselorAvailableOnDate(
    String counselorId,
    DateTime date,
  ) async {
    final slots = await getAvailableSlots(counselorId, date);
    return slots.any((slot) => slot.isAvailable);
  }

  /// Get all available dates for a counselor (next 30 days)
  Future<List<DateTime>> getAvailableDates(String counselorId) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final schedule = _counselorSchedules[counselorId];
    if (schedule == null) return [];

    final workingDays = schedule['workingDays'] as List<int>;
    final availableDates = <DateTime>[];
    final today = DateTime.now();

    for (int i = 0; i < 30; i++) {
      final date = today.add(Duration(days: i));
      if (workingDays.contains(date.weekday)) {
        availableDates.add(DateTime(date.year, date.month, date.day));
      }
    }

    return availableDates;
  }

  /// Book a slot (for testing)
  void bookSlot(String counselorId, DateTime date, TimeOfDay time) {
    if (!_bookedSlots.containsKey(counselorId)) {
      _bookedSlots[counselorId] = [];
    }
    
    _bookedSlots[counselorId]!.add({
      'date': date,
      'time': time,
    });
    
    print('📅 Booked: $counselorId on $date at ${time.hour}:${time.minute}');
  }
}