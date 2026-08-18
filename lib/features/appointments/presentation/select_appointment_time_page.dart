// lib/presentation/select_appointment_time_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../domain/time_slot.dart';
import '../infrastructure/mock_availability_repository.dart';

// lib/presentation/select_appointment_time_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

class SelectAppointmentTimePage extends ConsumerStatefulWidget {
  final String counselorId;
  final String counselorName;

  const SelectAppointmentTimePage({
    Key? key,
    required this.counselorId,
    required this.counselorName,
  }) : super(key: key);

  @override
  ConsumerState<SelectAppointmentTimePage> createState() => _SelectAppointmentTimePageState();
}

class _SelectAppointmentTimePageState extends ConsumerState<SelectAppointmentTimePage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  TimeOfDay? _selectedTime;
  List<TimeSlot> _availableSlots = [];
  bool _isLoadingSlots = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadAvailableSlots(_selectedDay!);
  }

  Future<void> _loadAvailableSlots(DateTime date) async {
    setState(() => _isLoadingSlots = true);

    final availabilityRepo = MockAvailabilityRepository();
    final slots = await availabilityRepo.getAvailableSlots(widget.counselorId, date);

    if (mounted) {
      setState(() {
        _availableSlots = slots;
        _isLoadingSlots = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Date & Time'),
        centerTitle: true,
      ),
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left side - Calendar
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCounselorInfo(),
                const SizedBox(height: 20),
                _buildCompactCalendar(),
              ],
            ),
          ),
        ),
        
        // Divider
        const VerticalDivider(width: 1),
        
        // Right side - Time slots
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Available Time Slots',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildTimeSlotGrid()),
              _buildConfirmButton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildCounselorInfo(),
        _buildCompactCalendar(),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.access_time, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Available Time Slots',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Expanded(child: _buildTimeSlotGrid()),
        _buildConfirmButton(),
      ],
    );
  }

  Widget _buildCounselorInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.teal.shade50,
      child: Row(
        children: [
          const CircleAvatar(
            radius: 22,
            backgroundColor: Colors.teal,
            child: Icon(Icons.person, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Counselor',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              Text(
                widget.counselorName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactCalendar() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 450),
      child: TableCalendar(
        firstDay: DateTime.now(),
        lastDay: DateTime.now().add(const Duration(days: 60)),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
            _selectedTime = null;
          });
          _loadAvailableSlots(selectedDay);
        },
        calendarFormat: CalendarFormat.month,
        availableCalendarFormats: const {CalendarFormat.month: 'Month'},
        headerStyle: const HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
          titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(fontSize: 12),
          weekendStyle: TextStyle(fontSize: 12),
        ),
        calendarStyle: CalendarStyle(
          cellMargin: const EdgeInsets.all(4),
          selectedDecoration: const BoxDecoration(
            color: Colors.teal,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: Colors.teal.shade200,
            shape: BoxShape.circle,
          ),
          defaultTextStyle: const TextStyle(fontSize: 13),
          weekendTextStyle: const TextStyle(fontSize: 13),
        ),
        rowHeight: 45,
      ),
    );
  }

  Widget _buildTimeSlotGrid() {
    if (_isLoadingSlots) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_availableSlots.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 56, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No available slots on this day',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.2,
      ),
      itemCount: _availableSlots.length,
      itemBuilder: (context, index) {
        final slot = _availableSlots[index];
        final isSelected = _selectedTime == slot.time;
        return _buildTimeSlotCard(slot, isSelected);
      },
    );
  }

  Widget _buildTimeSlotCard(TimeSlot slot, bool isSelected) {
    Color backgroundColor;
    Color textColor;
    Color borderColor;

    if (!slot.isAvailable) {
      backgroundColor = Colors.grey.shade200;
      textColor = Colors.grey.shade500;
      borderColor = Colors.grey.shade300;
    } else if (isSelected) {
      backgroundColor = Colors.teal;
      textColor = Colors.white;
      borderColor = Colors.teal;
    } else {
      backgroundColor = Colors.white;
      textColor = Colors.teal;
      borderColor = Colors.teal.shade200;
    }

    return InkWell(
      onTap: slot.isAvailable ? () => setState(() => _selectedTime = slot.time) : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor, width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            slot.formattedTime,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _selectedTime != null ? _confirmSelection : null,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: Colors.teal,
            disabledBackgroundColor: Colors.grey.shade300,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            _selectedTime == null ? 'Select a time slot' : 'Confirm Appointment',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  void _confirmSelection() {
    if (_selectedDay == null || _selectedTime == null) return;

    Navigator.pop(context, {
      'date': _selectedDay,
      'time': _selectedTime,
    });
  }
}