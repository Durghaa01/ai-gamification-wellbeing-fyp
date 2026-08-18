import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_mhproj/core/providers/app_providers.dart';
import 'package:flutter_application_mhproj/data/mindwell_repository.dart';
import 'package:flutter_application_mhproj/design_system/components/common_widgets.dart';
import 'package:flutter_application_mhproj/design_system/tokens/color_tokens.dart';
import 'package:flutter_application_mhproj/design_system/tokens/typography.dart';
import 'package:flutter_application_mhproj/ui/elements/responsive_page_scaffold.dart';
import 'package:flutter_application_mhproj/features/auth/presentation/role_selection_page.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key, required this.onThemeChanged});
  final ValueChanged<bool> onThemeChanged;
  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(mindWellRepositoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MindWellResponsiveScaffold(
      backgroundColor: MindWellColors.cream,
      appBar: AppBar(
        title: const Text('Administrator Panel'),
        actions: [
          Switch(value: isDark, onChanged: widget.onThemeChanged),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(isDark ? '☾' : '☀'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authService = ref.read(authServiceProvider);
              await authService.signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => RoleSelectionPage(
                    isDarkMode: isDark,
                    onThemeChanged: widget.onThemeChanged,
                  ),
                ),
                (route) => false,
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'User Management'),
            Tab(text: 'Clinic Management'),
          ],
        ),
      ),
      scrollable: false,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: TabBarView(
        controller: _tab,
        children: [
          const AdminUsersTab(),
          AdminClinicsTab(repository: repository),
        ],
      ),
      bottomNavigationBar: const CopyrightBar(),
    );
  }
}

class AdminUsersTab extends ConsumerWidget {
  const AdminUsersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersProvider);
    return usersAsync.when(
      data: (users) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Registered users：${users.length}',
                style: MindWellTypography.sectionSubtitle(
                  color: MindWellColors.darkGray,
                ).copyWith(fontSize: 20),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: users.isEmpty
                    ? Center(
                        child: Text(
                          'No users at the moment.',
                          style: MindWellTypography.body(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: users.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final u = users[i];
                          final initial = u.name.isNotEmpty
                              ? u.name[0].toUpperCase()
                              : (u.email.isNotEmpty
                                    ? u.email[0].toUpperCase()
                                    : '?');
                          return DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 14,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: MindWellColors.lightGreen
                                    .withOpacity(0.3),
                                child: Text(initial),
                              ),
                              title: Text(
                                u.name.isNotEmpty ? u.name : u.email,
                                style: MindWellTypography.cardTitle(
                                  color: MindWellColors.darkGray,
                                ),
                              ),
                              subtitle: Text(
                                '${u.email}\nRole: ${u.role.name}',
                                style: MindWellTypography.body(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              isThreeLine: true,
                              trailing: IconButton(
                                tooltip: 'Delete User',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  await ref
                                      .read(userDataServiceProvider)
                                      .deleteUser(u.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Removed ${u.email}'),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Unable to load users: $error',
          style: MindWellTypography.body(color: Colors.red.shade600),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class AdminClinicsTab extends StatelessWidget {
  const AdminClinicsTab({super.key, required this.repository});
  final MindWellRepository repository;

  @override
  Widget build(BuildContext context) {
    final clinics = repository.clinics;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Partner clinics：${clinics.length}',
                style: MindWellTypography.sectionSubtitle(
                  color: MindWellColors.darkGray,
                ).copyWith(fontSize: 20),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => _showCreateClinicDialog(context),
                icon: const Icon(Icons.add_business),
                label: const Text('Add New Clinic'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: clinics.isEmpty
                ? Center(
                    child: Text(
                      'No clinics created yet.',
                      style: MindWellTypography.body(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: clinics.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final c = clinics[i];
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 14,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.local_hospital_outlined),
                          title: Text(
                            c.name,
                            style: MindWellTypography.cardTitle(
                              color: MindWellColors.darkGray,
                            ),
                          ),
                          subtitle: Text(
                            c.address ?? '—',
                            style: MindWellTypography.body(
                              color: Colors.grey.shade600,
                            ),
                          ),
                          trailing: IconButton(
                            tooltip: 'Delete Clinic',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => repository.removeClinic(c),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showCreateClinicDialog(BuildContext context) {
    final repo = repository;
    final name = TextEditingController();
    final addr = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add New Clinic'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LabeledField(
              label: 'Clinic Name',
              icon: Icons.local_hospital,
              controller: name,
            ),
            const SizedBox(height: 10),
            LabeledField(
              label: 'Address',
              icon: Icons.place_outlined,
              controller: addr,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              repo.createClinic(
                name: name.text.trim(),
                address: addr.text.trim().isEmpty ? null : addr.text.trim(),
              );
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
