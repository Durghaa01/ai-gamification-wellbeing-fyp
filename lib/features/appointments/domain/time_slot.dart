// lib/domain/time_slot.dart
import 'package:flutter/material.dart';

class TimeSlot {
  final TimeOfDay time;
  final bool isAvailable;
  final String? reason; // Why it's unavailable

  const TimeSlot({
    required this.time,
    required this.isAvailable,
    this.reason,
  });

  String get formattedTime {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}



