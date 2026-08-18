// lib/domain/counselor_availability.dart
import 'time_slot.dart';


class CounselorAvailability {
  final String counselorId;
  final DateTime date;
  final List<TimeSlot> availableSlots;

  const CounselorAvailability({
    required this.counselorId,
    required this.date,
    required this.availableSlots,
  });
}