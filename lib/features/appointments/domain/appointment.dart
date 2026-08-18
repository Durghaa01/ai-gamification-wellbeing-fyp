import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class Appointment {
  final String id;
  final DateTime date;
  final TimeOfDay time;
  final String mode;
  final String userId;
  final String counselorId;
  final String? medication;
  final String? remark;

  Appointment({
    String? id,
    required this.date,
    required this.time,
    required this.mode,
    required this.userId,
    required this.counselorId,
    this.medication,
    this.remark,
  }) : id = id ?? const Uuid().v4();

  Appointment copyWith({
    String? id,
    DateTime? date,
    TimeOfDay? time,
    String? mode,
    String? userId,
    String? counselorId,
    String? medication,
    String? remark,
    
  }) {
    return Appointment(
      id: id ?? this.id,
      date: date ?? this.date,
      time: time ?? this.time,
      mode: mode ?? this.mode,
      userId: userId ?? this.userId,
      counselorId: counselorId ?? this.counselorId,
      medication: medication ?? this.medication,
      remark: remark ?? this.remark,
    );
  }

  String get formattedDate =>
      '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';

  String get formattedTime {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  // ✅ Fixed: Include all fields
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': DateTime(date.year, date.month, date.day).toIso8601String(),
      'time': {'hour': time.hour, 'minute': time.minute},
      'mode': mode,
      'userId': userId,
      'counselorId': counselorId,
      'medication': medication,
      'remark': remark,
    };
  }

  // ✅ Fixed: Parse all fields correctly
  static Appointment fromMap(Map<String, dynamic> data, {String? id}) {
    final dateRaw = data['date'];
    final timeRaw = data['time'] as Map<dynamic, dynamic>? ?? const {};
    final mode = (data['mode'] as String?) ?? 'Online';
    final counselorId = (data['counselorId'] as String?) ?? '';
    final userId = (data['userId'] as String?) ?? '';
    final medication = data['medication'] as String?;
    final remark = data['remark'] as String?;

    // Parse date
    DateTime parsedDate;
    if (dateRaw is DateTime) {
      parsedDate = dateRaw;
    } else if (dateRaw is String) {
      parsedDate = DateTime.tryParse(dateRaw) ?? DateTime.now();
    } else if (dateRaw is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(dateRaw);
    } else {
      parsedDate = DateTime.now();
    }

    // Parse time
    final hour = (timeRaw['hour'] as num?)?.toInt() ?? 9;
    final minute = (timeRaw['minute'] as num?)?.toInt() ?? 0;

    return Appointment(
      id: id ?? (data['id'] as String?),
      date: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      time: TimeOfDay(hour: hour, minute: minute),
      mode: mode,
      userId: userId,
      counselorId: counselorId,
      medication: medication,
      remark: remark,
    );
  }

  // ✅ Bonus: Add toJson/fromJson for consistency
  Map<String, dynamic> toJson() => toMap();

  factory Appointment.fromJson(Map<String, dynamic> json) => fromMap(json);
}
