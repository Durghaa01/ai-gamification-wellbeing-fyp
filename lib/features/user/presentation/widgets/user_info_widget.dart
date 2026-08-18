import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../design_system/components/common_widgets.dart';
import '../../../../design_system/tokens/color_tokens.dart';
import '../../../../design_system/tokens/typography.dart';
import '../user_info_page.dart';

/// Widget that displays user profile summary with edit button
class UserInfoWidget extends ConsumerWidget {
  const UserInfoWidget({
    super.key,
    this.onThemeChanged,
  });

  final Function(bool)? onThemeChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userInfoAsync = ref.watch(currentUserInfoProvider);
    final completenessAsync = ref.watch(profileCompletenessProvider);

    return userInfoAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            MindWellColors.lightGreen,
          ),
        ),
      ),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Error loading profile: $error',
            style: MindWellTypography.body(color: Colors.red),
          ),
        ),
      ),
      data: (userInfo) {
        if (userInfo == null) {
          return Center(
            child: Text(
              'Profile not found',
              style: MindWellTypography.body(),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile Header Card
              InputCard(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name and Status
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: MindWellColors.lightGreen
                                .withOpacity(0.3),
                            child: Text(
                              userInfo.displayName[0].toUpperCase(),
                              style: MindWellTypography.display(
                                color: MindWellColors.darkGray,
                              ).copyWith(fontSize: 32),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userInfo.displayName,
                                  style: MindWellTypography.cardTitle(
                                    color: MindWellColors.darkGray,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  userInfo.email,
                                  style: MindWellTypography.body(
                                    color: Colors.grey.shade600,
                                  ).copyWith(fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (userInfo.location != null &&
                                    userInfo.location!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          size: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            userInfo.location!,
                                            style: MindWellTypography.body(
                                              color: Colors.grey.shade600,
                                            ).copyWith(fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Profile Completeness Progress
                      _buildCompletenessBar(completenessAsync),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Quick Info Cards
              if (userInfo.age != null)
                _buildInfoCard(
                  icon: Icons.cake,
                  title: 'Age',
                  value: '${userInfo.age} years',
                ),
              if (userInfo.phoneNumber != null &&
                  userInfo.phoneNumber!.isNotEmpty)
                _buildInfoCard(
                  icon: Icons.phone,
                  title: 'Phone',
                  value: userInfo.phoneNumber!,
                ),
              if (userInfo.gender != null && userInfo.gender!.isNotEmpty)
                _buildInfoCard(
                  icon: Icons.wc,
                  title: 'Gender',
                  value: userInfo.gender!,
                ),

              const SizedBox(height: 16),

              // Bio Card
              if (userInfo.bio != null && userInfo.bio!.isNotEmpty)
                InputCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'About',
                          style: MindWellTypography.cardTitle(
                            color: MindWellColors.darkGray,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          userInfo.bio!,
                          style: MindWellTypography.body(
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Edit Button
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UserInfoPage(
                        onThemeChanged: onThemeChanged,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.edit),
                label: const Text('Edit Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MindWellColors.lightGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  /// Build completeness progress bar
  Widget _buildCompletenessBar(AsyncValue<int> completenessAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Profile Completeness',
              style: MindWellTypography.button(
                color: MindWellColors.darkGray,
              ).copyWith(fontSize: 12),
            ),
            completenessAsync.when(
              loading: () => const Text('Loading...'),
              error: (_, __) => const Text('Error'),
              data: (completeness) => Text(
                '$completeness%',
                style: MindWellTypography.button(
                  color: MindWellColors.lightGreen,
                ).copyWith(fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        completenessAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const LinearProgressIndicator(),
          data: (completeness) => ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: completeness / 100,
              minHeight: 6,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                MindWellColors.lightGreen,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Build info card
  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: MindWellColors.lightGreen, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: MindWellTypography.button(
                        color: Colors.grey.shade600,
                      ).copyWith(fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: MindWellTypography.body(
                        color: MindWellColors.darkGray,
                      ).copyWith(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
