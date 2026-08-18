import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_mhproj/core/providers/app_providers.dart';
import 'package:flutter_application_mhproj/design_system/tokens/color_tokens.dart';
import 'package:flutter_application_mhproj/design_system/tokens/typography.dart';
import 'package:flutter_application_mhproj/ui/elements/responsive_page_scaffold.dart';
import 'package:flutter_application_mhproj/widgets/sync_status_widgets.dart';
import '../application/appointment_controller.dart';
import '../domain/appointment.dart';
import 'add_appointment_page.dart';
//
import 'package:flutter_application_mhproj/features/appointments/presentation/appointment_detail_page.dart';
// import '../application/appointment_service.dart';
import '../application/application_provider.dart';
import './appointment_select_counselor_page.dart';



class AppointmentMainPage extends ConsumerStatefulWidget {
  static const routeName = '/appointments';

  final Function(bool) onThemeChanged;
  final bool isDarkMode;
  final String userId;

  const AppointmentMainPage({
    super.key,
    required this.onThemeChanged,
    required this.isDarkMode,
    required this.userId,
  });

  @override
  ConsumerState<AppointmentMainPage> createState() => _AppointmentMainPageState();
}

class _AppointmentMainPageState extends ConsumerState<AppointmentMainPage> {
  late bool _isDarkMode;
  bool _allowCounselorChange = true;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
  }

  Future<void> _navigateToAddAppointment() async {
  // Check if user is first-time
  final appointmentService = ref.read(appointmentServiceProvider);
  final isFirstTime = await appointmentService.isFirstTimeUser(widget.userId);
  
  if (!mounted) return; // Safety check after async
  
  if (isFirstTime) {
    // First visit -> Select counselor first
    final selectedCounselorId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => AppointmentSelectCounselorPage(
          userId: widget.userId,
        ),
      ),
    );
    
    // If counselor was selected, proceed to booking
    if (selectedCounselorId != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddAppointmentPage(
            userId: widget.userId,
            counselorId: selectedCounselorId,
            isFirstVisit: true,
            onThemeChanged: widget.onThemeChanged,
            isDarkMode: _isDarkMode,
            allowCounselorChange: _allowCounselorChange,
          ),
        ),
      );
    }
  } else {
    // Returning user -> Get assigned counselor and go directly to booking
    final assignedCounselorId = await appointmentService.getAssignedCounselorId(widget.userId);
    
    if (!mounted) return;
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddAppointmentPage(
          userId: widget.userId,
          counselorId: assignedCounselorId,
          isFirstVisit: false,
          onThemeChanged: widget.onThemeChanged,
          isDarkMode: _isDarkMode,
          allowCounselorChange: true, // Allow them to change if they want
        ),
      ),
    );
  }
}

  void _navigateToAppointmentDetail(Appointment appointment) {
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => AppointmentDetailPage(
          appointment:appointment,
          onThemeChanged: widget.onThemeChanged,
          isDarkMode: _isDarkMode,)
      )
    );
  }


  @override
  Widget build(BuildContext context) {
    final appointments = ref.watch(appointmentControllerProvider);
    return MindWellResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Appointment'),
        centerTitle: true,
        actions: [
          // Sync status indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SyncStatusIndicator(showLabel: false, compact: true),
          ),
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
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_box, size: 20),
              label: const Text("Add a New Appointment"),
              style: ElevatedButton.styleFrom(
                backgroundColor: MindWellColors.darkGray,
                foregroundColor: MindWellColors.cream,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
              ),
              onPressed: _navigateToAddAppointment,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Current Appointments',
            style: MindWellTypography.sectionSubtitle(
              color: MindWellColors.darkGray,
            ).copyWith(fontSize: 20),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: appointments.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final appointment = appointments[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    leading: Icon(
                      appointment.mode == "Online"
                          ? Icons.videocam
                          : Icons.meeting_room,
                      color: MindWellColors.darkGray,
                    ),
                    title: Text(
                      "${appointment.formattedDate} at ${appointment.formattedTime}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(appointment.mode),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _navigateToAppointmentDetail(appointment),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
