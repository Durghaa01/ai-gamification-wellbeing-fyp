import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_mhproj/core/providers/app_providers.dart';
import 'package:flutter_application_mhproj/design_system/components/common_widgets.dart';
import 'package:flutter_application_mhproj/design_system/tokens/color_tokens.dart';
import 'package:flutter_application_mhproj/design_system/tokens/typography.dart';
import 'package:flutter_application_mhproj/data/mindwell_repository.dart';
import 'package:flutter_application_mhproj/models/models.dart';
import 'package:flutter_application_mhproj/ui/elements/responsive_page_scaffold.dart';
import 'package:flutter_application_mhproj/features/auth/presentation/role_selection_page.dart';
import 'package:flutter_application_mhproj/features/clinic/presentation/clinic_journal_detail_page.dart';

enum _SortBy { name, email }

class ClinicDashboardPage extends ConsumerStatefulWidget {
  const ClinicDashboardPage({super.key, required this.onThemeChanged});
  final ValueChanged<bool> onThemeChanged;
  @override
  ConsumerState<ClinicDashboardPage> createState() =>
      _ClinicDashboardPageState();
}

class _ClinicDashboardPageState extends ConsumerState<ClinicDashboardPage> {
  final TextEditingController search = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Timer? _debounce;
  _SortBy _sortBy = _SortBy.name;
  bool _ascending = true;

  @override
  void dispose() {
    _debounce?.cancel();
    search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(mindWellRepositoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final clinics = repository.clinics;
    final clinic = clinics.isNotEmpty ? clinics.first : null;
    final q = search.text.trim().toLowerCase();

    final filtered =
        clinic == null
              ? <AppUser>[]
              : clinic.patients
                    .where(
                      (p) =>
                          q.isEmpty ||
                          p.name.toLowerCase().contains(q) ||
                          p.email.toLowerCase().contains(q),
                    )
                    .toList()
          ..sort((a, b) {
            int cmp;
            switch (_sortBy) {
              case _SortBy.email:
                cmp = a.email.toLowerCase().compareTo(b.email.toLowerCase());
                break;
              case _SortBy.name:
                cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
                break;
            }
            return _ascending ? cmp : -cmp;
          });

    return MindWellResponsiveScaffold(
      backgroundColor: MindWellColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text(
          clinic != null ? 'Clinic panel — ${clinic.name}' : 'Clinic panel',
        ),
        actions: [
          IconButton(
            tooltip: 'Clear search',
            onPressed: () {
              if (search.text.isNotEmpty) {
                search.clear();
                setState(() {});
              }
            },
            icon: const Icon(Icons.clear_all),
          ),
          PopupMenuButton<dynamic>(
            tooltip: 'Sorting',
            onSelected: (value) {
              if (value == 'name' || value == 'email') {
                setState(
                  () =>
                      _sortBy = value == 'name' ? _SortBy.name : _SortBy.email,
                );
              } else if (value == 'dir') {
                setState(() => _ascending = !_ascending);
              }
            },
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: 'name',
                checked: _sortBy == _SortBy.name,
                child: const Text('Sorting by name'),
              ),
              CheckedPopupMenuItem(
                value: 'email',
                checked: _sortBy == _SortBy.email,
                child: const Text('Sorting by email'),
              ),
              PopupMenuItem(
                value: 'dir',
                child: Row(
                  children: [
                    Icon(
                      _ascending ? Icons.arrow_upward : Icons.arrow_downward,
                    ),
                    const SizedBox(width: 8),
                    Text(_ascending ? 'Ascending' : 'Descending'),
                  ],
                ),
              ),
            ],
            icon: const Icon(Icons.sort),
          ),
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
      ),
      scrollable: false,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: search,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search patient name/email',
                        ),
                        onChanged: (_) {
                          _debounce?.cancel();
                          _debounce = Timer(
                            const Duration(milliseconds: 250),
                            () => setState(() {}),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: clinic == null
                          ? null
                          : () => _showAddPatientDialog(clinic),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Add manually'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Matches：${filtered.length}',
                  style: MindWellTypography.body(
                    color: MindWellColors.darkGray,
                  ).copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: clinic == null
                ? const _NoClinicState()
                : filtered.isEmpty
                ? _EmptyState(onAdd: () => _showAddPatientDialog(clinic))
                : LayoutBuilder(
                    builder: (_, c) {
                      final cross = c.maxWidth >= 1100
                          ? 3
                          : (c.maxWidth >= 820 ? 2 : 1);
                      return Scrollbar(
                        controller: _scroll,
                        child: GridView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.only(bottom: 16),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cross,
                                crossAxisSpacing: 18,
                                mainAxisSpacing: 18,
                                childAspectRatio: 1.5,
                              ),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _PatientCard(
                            key: ValueKey(filtered[i].id),
                            user: filtered[i],
                            repository: repository,
                            onChanged: () => setState(() {}),
                            onRemove: () {
                              repository.removePatientFromClinic(
                                clinic,
                                filtered[i],
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Removed from clinic'),
                                ),
                              );
                            },
                            onThemeChanged: widget.onThemeChanged,
                            isDarkMode: isDark,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const CopyrightBar(),
    );
  }

  void _showAddPatientDialog(Clinic clinic) {
    final repository = ref.read(mindWellRepositoryProvider);
    final name = TextEditingController();
    final email = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add patient manually'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LabeledField(
              label: 'Surname',
              icon: Icons.person_outline,
              controller: name,
            ),
            const SizedBox(height: 10),
            LabeledField(
              label: 'Email',
              icon: Icons.email_outlined,
              controller: email,
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
              final nm = name.text.trim();
              final em = email.text.trim();
              if (nm.isEmpty || em.isEmpty || !em.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid name and email'),
                  ),
                );
                return;
              }
              final existing = repository.findUserByEmail(em);
              final user = existing ?? repository.createUser(nm, em);
              final exists = clinic.patients.any(
                (p) => p.email.toLowerCase() == user.email.toLowerCase(),
              );
              if (exists) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('This patient is already in the list.'),
                  ),
                );
                return;
              }
              repository.addPatientToClinic(clinic, user);
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Added：${user.name}')));
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_search,
            size: 64,
            color: Theme.of(context).primaryColor.withOpacity(0.6),
          ),
          const SizedBox(height: 12),
          Text(
            'No matching patient.',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Try a shorter keyword, or add manually.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Add manually'),
          ),
        ],
      ),
    );
  }
}

class _NoClinicState extends StatelessWidget {
  const _NoClinicState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_hospital_outlined,
            size: 72,
            color: MindWellColors.darkGray.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No clinic configured yet',
            style: MindWellTypography.sectionSubtitle(
              color: MindWellColors.darkGray,
            ).copyWith(fontSize: 20),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Head to the admin panel to create a clinic before managing patients.',
            style: MindWellTypography.body(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PatientCard extends StatefulWidget {
  const _PatientCard({
    super.key,
    required this.user,
    required this.repository,
    required this.onChanged,
    required this.onRemove,
    required this.onThemeChanged,
    required this.isDarkMode,
  });
  final AppUser user;
  final MindWellRepository repository;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  final ValueChanged<bool> onThemeChanged;
  final bool isDarkMode;

  @override
  State<_PatientCard> createState() => _PatientCardState();
}

class _PatientCardState extends State<_PatientCard> {
  late final TextEditingController notesController;
  @override
  void initState() {
    super.initState();
    notesController = TextEditingController(text: widget.user.notes);
  }

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  Future<void> _confirmRemove() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove from clinic?'),
        content: Text(
          'Confirm removing ${widget.user.name} from the current clinic？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) widget.onRemove();
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.user.name.isNotEmpty
        ? widget.user.name[0].toUpperCase()
        : '?';
    return DecoratedBox(
      decoration: BoxDecoration(
        color:
            widget.isDarkMode ? const Color(0xFF232825) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: MindWellColors.lightGreen.withOpacity(0.25),
                  child: Text(initial),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.user.name,
                        style: MindWellTypography.cardTitle(
                          color: widget.isDarkMode
                              ? Colors.white
                              : MindWellColors.darkGray,
                        ),
                      ),
                      Text(
                        widget.user.email,
                        style: MindWellTypography.body(
                          color: widget.isDarkMode
                              ? Colors.white70
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Save notes',
                  onPressed: () {
                    widget.repository.saveUserNotes(
                      widget.user,
                      notesController.text,
                    );
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('Saved')));
                    widget.onChanged();
                  },
                  icon: const Icon(Icons.save_alt),
                ),
                IconButton(
                  tooltip: 'View journal',
                  onPressed: _openJournal,
                  icon: const Icon(Icons.menu_book_outlined),
                ),
                IconButton(
                  tooltip: 'Remove from clinic',
                  onPressed: _confirmRemove,
                  icon: const Icon(Icons.person_remove_alt_1_outlined),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: notesController,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  labelText: 'Notes / Symptom records / Allergy history',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                Chip(
                  avatar: Icon(Icons.bar_chart, size: 16),
                  label: Text('Recent physical exam: normal'),
                ),
                Chip(
                  avatar: Icon(Icons.favorite_border, size: 16),
                  label: Text('Heart beat：72 bpm'),
                ),
                Chip(
                  avatar: Icon(Icons.bloodtype_outlined, size: 16),
                  label: Text('Blood type：O'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openJournal() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClinicJournalDetailPage(
          patient: widget.user,
          onThemeChanged: widget.onThemeChanged,
        ),
      ),
    );
  }
}
