import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_mhproj/design_system/tokens/color_tokens.dart';

import '../application/appointment_controller.dart';
import '../domain/appointment.dart';

class AppointmentDetailPage extends ConsumerStatefulWidget {
  final Appointment appointment;

  final Function(bool) onThemeChanged;
  final bool isDarkMode;

  const AppointmentDetailPage({
    
    super.key, 
    required this.appointment, 
    required this.onThemeChanged, 
    required this.isDarkMode
    
    });

  @override
  ConsumerState<AppointmentDetailPage> createState() => _AppointmentDetailPageState();
}

class _AppointmentDetailPageState extends ConsumerState<AppointmentDetailPage> {
  late TextEditingController _medicationController;
  late TextEditingController _remarkController;
  late Appointment _currentAppointment;
  final String testName = "Ms Kar Yean Yeap";

  @override
  void initState() {
    super.initState();
    _currentAppointment = widget.appointment;
    _medicationController = TextEditingController(text: _currentAppointment.medication);
    _remarkController = TextEditingController(text: _currentAppointment.remark);
  }

  void _saveChanges() {
    setState(() {
      _currentAppointment = _currentAppointment.copyWith(
        medication: _medicationController.text,
        remark: _remarkController.text,
      );
    });
    
    Navigator.pop(context, _currentAppointment);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Changes saved successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveChanges,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentAppointment.userId.toString(),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ID: ${_currentAppointment.id}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildInfoCard('Date', _currentAppointment.date.toString(), Icons.calendar_today),
            _buildInfoCard('Time', _currentAppointment.time.toString(), Icons.access_time),
            _buildInfoCard('Mode', _currentAppointment.mode, Icons.videocam),
            _buildInfoCard('Counselor', testName, Icons.portrait),
            const SizedBox(height: 20),
            Text(
              _currentAppointment.counselorId.toString()
            ),
            const SizedBox(height: 20),
            const Text(
              'Medication',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _medicationController,
              decoration: InputDecoration(
                hintText: 'Enter medication details',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            const Text(
              'Remark',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _remarkController,
              decoration: InputDecoration(
                hintText: 'Enter remarks',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveChanges,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Save Changes', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
          leading: Icon(icon, color: MindWellColors.lightGreen),
        title: Text(label, style: const TextStyle(color: Colors.grey)),
        subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      ),
    );
  }

  @override
  void dispose() {
    _medicationController.dispose();
    _remarkController.dispose();
    super.dispose();
  }
}