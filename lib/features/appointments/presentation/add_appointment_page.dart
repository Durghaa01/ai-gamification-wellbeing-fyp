import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_mhproj/design_system/tokens/color_tokens.dart';
import 'package:flutter_application_mhproj/design_system/tokens/typography.dart';
import 'package:flutter_application_mhproj/ui/elements/responsive_page_scaffold.dart';

import '../application/appointment_controller.dart';
import '../domain/appointment.dart';
import 'select_appointment_time_page.dart';

class AddAppointmentPage extends ConsumerStatefulWidget {
  final ValueChanged<bool> onThemeChanged;
  final bool isDarkMode;
  final String userId;
  final String? counselorId;
  final String? counselorName;
  final bool isFirstVisit;
  final bool allowCounselorChange;

  const AddAppointmentPage({
    super.key,
    required this.onThemeChanged,
    required this.isDarkMode,
    required this.userId,
    this.counselorId,
    this.counselorName,
    this.isFirstVisit = false,
    this.allowCounselorChange = false,
  });

  @override
  ConsumerState<AddAppointmentPage> createState() => _AddAppointmentPageState();
}

class _AddAppointmentPageState extends ConsumerState<AddAppointmentPage> {
  late bool _isDarkMode;
  TimeOfDay? _selectedTime;
  DateTime? _selectedDate;
  String _selectedMode = 'Online';
  String? _selectedCounselorId;
  String? _selectedCounselorName;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _medicationController = TextEditingController();
  final _remarkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
    _selectedCounselorId = widget.counselorId;
    _selectedCounselorName = widget.counselorName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _medicationController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  /// Navigate to the time selection page with calendar and availability
  Future<void> _selectDateTime() async {
    if (_selectedCounselorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a counselor first')),
      );
      return;
    }

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => SelectAppointmentTimePage(
          counselorId: _selectedCounselorId!,
          counselorName: _selectedCounselorName ?? 'Counselor',
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedDate = result['date'] as DateTime;
        _selectedTime = result['time'] as TimeOfDay;
      });
    }
  }

  /// Build the appointment object from form data
  Appointment _buildAppointment() {
    return Appointment(
      userId: widget.userId,
      counselorId: _selectedCounselorId!,
      date: _selectedDate!,
      time: _selectedTime!,
      mode: _selectedMode,
      medication: _medicationController.text.trim().isEmpty
          ? null
          : _medicationController.text.trim(),
      remark: _remarkController.text.trim().isEmpty
          ? null
          : _remarkController.text.trim(),
    );
  }

  /// Save the appointment
  void _saveAppointment() {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if date and time are selected
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date and time.')),
      );
      return;
    }

    // Check if counselor is selected
    if (_selectedCounselorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a counselor.')),
      );
      return;
    }

    // Add appointment to controller
    final appointment = _buildAppointment();
    ref.read(appointmentControllerProvider.notifier).add(appointment);

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Appointment saved successfully!'),
        backgroundColor: Colors.green,
      ),
    );

    // Navigate back
    Navigator.pop(context, appointment);
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: MindWellColors.lightGreen),
        title: Text(label, style: const TextStyle(color: Colors.grey)),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MindWellResponsiveScaffold(
      appBar: AppBar(
        title: Text(
          'Add a New Appointment',
          style: MindWellTypography.sectionSubtitle(
            color: MindWellColors.darkGray,
          ).copyWith(fontSize: 20),
        ),
        centerTitle: true,
        actions: [
          Switch(
            value: _isDarkMode,
            onChanged: (value) {
              setState(() => _isDarkMode = value);
              widget.onThemeChanged(value);
            },
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(_isDarkMode ? '☾' : '☀'),
          ),
        ],
      ),
      scrollable: false,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            // Counselor Information
            if (_selectedCounselorName != null) ...[
              _buildInfoCard(
                'Counselor',
                _selectedCounselorName!,
                Icons.person,
              ),
              if (widget.allowCounselorChange)
                TextButton.icon(
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Change Counselor'),
                  onPressed: () {
                    // TODO: Navigate to counselor selection
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Counselor change feature coming soon'),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 20),
            ],

            // Name Field
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.person_outline),
                hintText: 'Enter your name',
                labelText: 'Name (Optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Date & Time Selection (Combined)
            const Text(
              'Date & Time',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _selectDateTime,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade50,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.teal),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedDate != null && _selectedTime != null
                                ? 'Selected Date & Time'
                                : 'Choose date and time',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (_selectedDate != null && _selectedTime != null)
                            Text(
                              '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year} at ${_selectedTime!.hour}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Appointment Mode
            const Text(
              'Appointment Mode',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildModeOption('Online', Icons.videocam),
                _buildModeOption('In-Person', Icons.meeting_room),
                _buildModeOption('Phone Call', Icons.phone),
              ],
            ),
            const SizedBox(height: 20),

            // Medication Field (Optional)
            TextFormField(
              controller: _medicationController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.medication),
                hintText: 'Current medication (if any)',
                labelText: 'Medication',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // Remark Field (Optional)
            TextFormField(
              controller: _remarkController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.note),
                hintText: 'Any additional notes',
                labelText: 'Remarks',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 32),

            // First Visit Indicator
            if (widget.isFirstVisit)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This is your first appointment. Welcome!',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Save Button
            ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Save Appointment'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: MindWellColors.darkGray,
                foregroundColor: MindWellColors.cream,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _saveAppointment,
            ),
            const SizedBox(height: 12),

            // Helper Text
            Text(
              'Your appointment will appear in the list on the previous screen.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build mode selection option
  Widget _buildModeOption(String mode, IconData icon) {
    final isSelected = _selectedMode == mode;
    
    return InkWell(
      onTap: () => setState(() => _selectedMode = mode),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? MindWellColors.lightGreen : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? MindWellColors.darkGray : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade700,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              mode,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
