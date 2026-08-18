// lib/features/appointments/presentation/appointment_select_counselor_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppointmentSelectCounselorPage extends ConsumerWidget {
  final String userId;

  const AppointmentSelectCounselorPage({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mock counselors for now
    final counselors = [
      {'id': 'counselor-1', 'name': 'Ms Kar Yean Yeap', 'specialization': 'Anxiety & Depression'},
      {'id': 'counselor-2', 'name': 'Dr. Michael Chen', 'specialization': 'Family Therapy'},
      {'id': 'counselor-3', 'name': 'Dr. Emily Rodriguez', 'specialization': 'Trauma & PTSD'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select a Counselor'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome! 👋',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please select a counselor for your first appointment.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: counselors.length,
                itemBuilder: (context, index) {
                  final counselor = counselors[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.teal,
                        child: Text(
                          counselor['name']![0],
                          style: const TextStyle(
                            fontSize: 24,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        counselor['name']!,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          counselor['specialization']!,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      trailing: ElevatedButton(
                        onPressed: () {
                          // Return the selected counselor ID
                          Navigator.pop(context, counselor['id']);
                        },
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Select'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}