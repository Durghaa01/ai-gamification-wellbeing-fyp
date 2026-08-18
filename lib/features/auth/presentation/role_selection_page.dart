import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_mhproj/core/providers/app_providers.dart';
import 'package:flutter_application_mhproj/design_system/components/common_widgets.dart';
import 'package:flutter_application_mhproj/design_system/tokens/color_tokens.dart';
import 'package:flutter_application_mhproj/design_system/tokens/typography.dart';
import 'package:flutter_application_mhproj/ui/elements/responsive_page_scaffold.dart';
import 'package:flutter_application_mhproj/core/routes/app_routes.dart';

class RoleSelectionPage extends ConsumerWidget {
  const RoleSelectionPage({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(mindWellRepositoryProvider);
    return MindWellResponsiveScaffold(
      backgroundColor: MindWellColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'MindWell Access',
          style: MindWellTypography.sectionSubtitle(
            color: MindWellColors.darkGray,
          ).copyWith(fontSize: 22),
        ),
        actions: [
          Switch(value: isDarkMode, onChanged: onThemeChanged),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(isDarkMode ? '☾' : '☀'),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose your portal',
                textAlign: TextAlign.center,
                style: MindWellTypography.sectionTitle(
                  color: MindWellColors.darkGray,
                ).copyWith(fontSize: 36),
              ),
              const SizedBox(height: 16),
              Text(
                'Select the entry that matches your role to continue to the tailored experience.',
                textAlign: TextAlign.center,
                style: MindWellTypography.body(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 36),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 24,
                runSpacing: 24,
                children: [
                  RoleCard(
                    icon: Icons.person_rounded,
                    title: 'User Login',
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.userLogin,
                    ),
                  ),
                  RoleCard(
                    icon: Icons.medical_services_rounded,
                    title: 'Clinic Login',
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.clinicLogin,
                    ),
                  ),
                  RoleCard(
                    icon: Icons.admin_panel_settings_rounded,
                    title: 'Admin Login',
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.adminLogin,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const CopyrightBar(),
    );
  }
}
