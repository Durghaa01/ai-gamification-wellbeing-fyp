import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../design_system/components/common_widgets.dart';
import '../../../design_system/tokens/color_tokens.dart';
import '../../../design_system/tokens/typography.dart';
import '../../../models/user_info.dart' as user_profile;
import '../../../services/user_info_service.dart';
import '../../../ui/elements/responsive_page_scaffold.dart';
import '../../../widgets/sync_status_widgets.dart';

/// Complete user profile edit page with form validation, persistence, and real-time sync
class UserInfoPage extends ConsumerStatefulWidget {
  const UserInfoPage({super.key, this.onThemeChanged});

  final Function(bool)? onThemeChanged;

  @override
  ConsumerState<UserInfoPage> createState() => _UserInfoPageState();
}

class _UserInfoPageState extends ConsumerState<UserInfoPage> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _bioController;
  late TextEditingController _locationController;
  late TextEditingController _genderController;
  late TextEditingController _dobController;
  late ScrollController _scrollController;
  late FocusNode _phoneFocusNode;
  late FocusNode _bioFocusNode;
  late FocusNode _locationFocusNode;
  late FocusNode _genderFocusNode;
  late FocusNode _dobFocusNode;

  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _hasChanges = false;
  String? _errorMessage;
  bool _darkNotifications = true;
  bool _darkMode = false;
  String _privacyLevel = 'private';
  List<_ManualFieldDescriptor> _missingFields = const [];

  final Map<String, GlobalKey> _fieldKeys = {
    'phone': GlobalKey(),
    'bio': GlobalKey(),
    'location': GlobalKey(),
    'gender': GlobalKey(),
    'dob': GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _bioController = TextEditingController();
    _locationController = TextEditingController();
    _genderController = TextEditingController();
    _dobController = TextEditingController();
    _scrollController = ScrollController();
    _phoneFocusNode = FocusNode();
    _bioFocusNode = FocusNode();
    _locationFocusNode = FocusNode();
    _genderFocusNode = FocusNode();
    _dobFocusNode = FocusNode();
  }

  List<_ManualFieldDescriptor> _computeMissingFields() {
    final fields = <_ManualFieldDescriptor>[];
    if (_phoneController.text.trim().isEmpty) {
      fields.add(
        const _ManualFieldDescriptor(
          id: 'phone',
          label: 'Phone Number',
          icon: Icons.phone,
          helper: 'Add a contact number so clinics can reach you.',
        ),
      );
    }
    if (_locationController.text.trim().isEmpty) {
      fields.add(
        const _ManualFieldDescriptor(
          id: 'location',
          label: 'Location',
          icon: Icons.location_on,
          helper: 'Share your city or region for better matching.',
        ),
      );
    }
    if (_genderController.text.trim().isEmpty) {
      fields.add(
        const _ManualFieldDescriptor(
          id: 'gender',
          label: 'Gender',
          icon: Icons.wc,
          helper: 'Let clinicians tailor the experience to you.',
        ),
      );
    }
    if (_dobController.text.trim().isEmpty) {
      fields.add(
        const _ManualFieldDescriptor(
          id: 'dob',
          label: 'Date of Birth',
          icon: Icons.cake,
          helper: 'Age helps personalise recommendations and insights.',
        ),
      );
    }
    if (_bioController.text.trim().isEmpty) {
      fields.add(
        const _ManualFieldDescriptor(
          id: 'bio',
          label: 'Bio',
          icon: Icons.text_snippet,
          helper: 'Describe yourself to help your care team know you better.',
        ),
      );
    }
    return fields;
  }

  FocusNode? _focusNodeFor(String fieldId) {
    switch (fieldId) {
      case 'phone':
        return _phoneFocusNode;
      case 'bio':
        return _bioFocusNode;
      case 'location':
        return _locationFocusNode;
      case 'gender':
        return _genderFocusNode;
      case 'dob':
        return _dobFocusNode;
      default:
        return null;
    }
  }

  Future<void> _scrollToField(String fieldId) async {
    final key = _fieldKeys[fieldId];
    if (key?.currentContext != null) {
      await Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
    }
    final focus = _focusNodeFor(fieldId);
    if (focus != null) {
      focus.requestFocus();
    }
    if (fieldId == 'dob') {
      await Future.delayed(const Duration(milliseconds: 120));
      if (mounted) {
        await _pickDateOfBirth();
      }
    }
  }

  Future<void> _openManualFillSheet() async {
    if (_missingFields.isEmpty) {
      return;
    }

    final beforeSnapshot = _snapshotManualFields();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _ManualFillSheet(
        missingFields: _missingFields,
        phoneController: _phoneController,
        bioController: _bioController,
        locationController: _locationController,
        genderController: _genderController,
        dobController: _dobController,
        onPickDob: _pickDateOfBirth,
      ),
    );

    if (!mounted) return;
    final afterSnapshot = _snapshotManualFields();
    final didChange = beforeSnapshot != afterSnapshot;

    setState(() {
      if (didChange) {
        _hasChanges = true;
      }
      _missingFields = _computeMissingFields();
    });
  }

  String _snapshotManualFields() {
    final values = {
      'phone': _phoneController.text.trim(),
      'bio': _bioController.text.trim(),
      'location': _locationController.text.trim(),
      'gender': _genderController.text.trim(),
      'dob': _dobController.text.trim(),
    };
    return values.values.join('|');
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final existing = _dobController.text.trim().isNotEmpty
        ? DateTime.tryParse(_dobController.text.trim())
        : null;
    final initialDate = existing != null && !existing.isAfter(now)
        ? existing
        : now;
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (selected != null && mounted) {
      setState(() {
        _dobController.text = selected.toIso8601String().split('T').first;
        _hasChanges = true;
        _missingFields = _computeMissingFields();
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _genderController.dispose();
    _dobController.dispose();
    _scrollController.dispose();
    _phoneFocusNode.dispose();
    _bioFocusNode.dispose();
    _locationFocusNode.dispose();
    _genderFocusNode.dispose();
    _dobFocusNode.dispose();
    super.dispose();
  }

  /// Load user info into form
  void _loadUserInfo(user_profile.UserInfo userInfo) {
    _nameController.text = userInfo.displayName;
    _emailController.text = userInfo.email;
    _phoneController.text = userInfo.phoneNumber ?? '';
    _bioController.text = userInfo.bio ?? '';
    _locationController.text = userInfo.location ?? '';
    _genderController.text = userInfo.gender ?? '';
    if (userInfo.dateOfBirth != null) {
      _dobController.text = userInfo.dateOfBirth!.toString().split(' ')[0];
    }
    _darkMode = userInfo.preferences['darkMode'] as bool? ?? false;
    _darkNotifications = userInfo.preferences['notifications'] as bool? ?? true;
    _privacyLevel =
        userInfo.preferences['privacyLevel'] as String? ?? 'private';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _missingFields = _computeMissingFields();
        _hasChanges = false;
      });
    });
  }

  /// Handle form submission with sync queueing
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final userId = await ref.read(currentUserIdProvider.future);
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final userInfoService = ref.read(userInfoServiceProvider);

      // Parse date of birth
      DateTime? dateOfBirth;
      if (_dobController.text.isNotEmpty) {
        try {
          dateOfBirth = DateTime.parse(_dobController.text);
        } catch (e) {
          setState(() => _errorMessage = 'Invalid date format');
          return;
        }
      }

      // Get current user info to preserve other fields
      final currentInfo = await userInfoService.getUserInfo(userId);
      if (currentInfo == null) {
        throw Exception('User profile not found');
      }

      // Create updated user info
      final updatedInfo = currentInfo.copyWith(
        displayName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.isNotEmpty
            ? _phoneController.text
            : null,
        bio: _bioController.text.isNotEmpty ? _bioController.text : null,
        location: _locationController.text.isNotEmpty
            ? _locationController.text
            : null,
        gender: _genderController.text.isNotEmpty
            ? _genderController.text
            : null,
        dateOfBirth: dateOfBirth,
        preferences: {
          'darkMode': _darkMode,
          'notifications': _darkNotifications,
          'privacyLevel': _privacyLevel,
          'emailNotifications': true,
        },
      );

      // Validate all fields
      final validationErrors = updatedInfo.validateAll();
      if (validationErrors.isNotEmpty) {
        setState(() {
          _errorMessage = validationErrors.values.first;
        });
        return;
      }

      await userInfoService.updateUserInfo(updatedInfo);

      if (mounted) {
        // Refresh the user info provider
        ref.refresh(currentUserInfoProvider);
        ref.refresh(profileCompletenessProvider);

        // Show success dialog
        await _showSuccessDialog(
          title: 'Profile Saved',
          message: 'Your profile has been saved successfully.',
        );

        setState(() {
          _hasChanges = false;
          _missingFields = _computeMissingFields();
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating profile: $e');
      }
      if (mounted) {
        await _showErrorDialog(
          title: 'Update Failed',
          message:
              _errorMessage ?? 'Failed to update profile. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  /// Show success dialog
  Future<void> _showSuccessDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF232825)
            : Colors.white,
        titleTextStyle: MindWellTypography.sectionSubtitle(
          color: MindWellColors.lightGreen,
        ).copyWith(fontSize: 18),
        contentTextStyle: MindWellTypography.body(color: Colors.grey.shade700),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: MindWellTypography.button(
                color: MindWellColors.lightGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show error dialog
  Future<void> _showErrorDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF232825)
            : Colors.white,
        titleTextStyle: MindWellTypography.sectionSubtitle(
          color: Colors.red.shade700,
        ).copyWith(fontSize: 18),
        contentTextStyle: MindWellTypography.body(color: Colors.grey.shade700),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: MindWellTypography.button(color: MindWellColors.darkGray),
            ),
          ),
        ],
      ),
    );
  }

  /// Show unsaved changes warning
  Future<bool> _showUnsavedWarning() async {
    if (!_hasChanges) {
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
          'You have unsaved changes. Do you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: _showUnsavedWarning,
      child: MindWellResponsiveScaffold(
        backgroundColor: MindWellColors.cream,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'User Profile',
            style: MindWellTypography.sectionSubtitle(
              color: MindWellColors.darkGray,
            ).copyWith(fontSize: 22),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: MindWellColors.darkGray),
            onPressed: () async {
              if (await _showUnsavedWarning()) {
                if (mounted) Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            // Sync status indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SyncStatusIndicator(showLabel: true, compact: false),
            ),
            Switch(value: isDark, onChanged: widget.onThemeChanged),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(isDark ? '☾' : '☀'),
            ),
          ],
        ),
        child: Consumer(
          builder: (context, ref, child) {
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

                // Load data on first build
                if (_nameController.text.isEmpty) {
                  _loadUserInfo(userInfo);
                }

                return Stack(
                  children: [
                    Form(
                      key: _formKey,
                      onChanged: () {
                        setState(() {
                          _hasChanges = true;
                          _missingFields = _computeMissingFields();
                        });
                      },
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Profile Completeness Card
                            _buildCompletenessCard(completenessAsync),
                            const SizedBox(height: 16),
                            if (_missingFields.isNotEmpty) ...[
                              _buildManualCompletionCard(),
                              const SizedBox(height: 24),
                            ],
                            const SizedBox(height: 24),

                            // Basic Information Section
                            Text(
                              'Basic Information',
                              style: MindWellTypography.sectionSubtitle(
                                color: MindWellColors.darkGray,
                              ).copyWith(fontSize: 20),
                            ),
                            const SizedBox(height: 16),

                            // Name Field
                            InputCard(
                              child: TextFormField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  labelText: 'Display Name',
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(16),
                                  labelStyle: MindWellTypography.body(
                                    color: MindWellColors.darkGray,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.person,
                                    color: MindWellColors.darkGray,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Display name is required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Email Field (Read-only)
                            InputCard(
                              child: TextFormField(
                                controller: _emailController,
                                enabled: false,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(16),
                                  labelStyle: MindWellTypography.body(
                                    color: Colors.grey,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.email,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Phone Field
                            KeyedSubtree(
                              key: _fieldKeys['phone'],
                              child: InputCard(
                                child: TextFormField(
                                  controller: _phoneController,
                                  focusNode: _phoneFocusNode,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    labelText: 'Phone Number (Optional)',
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.all(16),
                                    labelStyle: MindWellTypography.body(
                                      color: MindWellColors.darkGray,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.phone,
                                      color: MindWellColors.darkGray,
                                    ),
                                    hintText: '+1 (555) 000-0000',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return null;
                                    }
                                    final digits = value.replaceAll(
                                      RegExp(r'\D'),
                                      '',
                                    );
                                    if (digits.length < 10) {
                                      return 'Phone number must have at least 10 digits';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Additional Information Section
                            Text(
                              'Additional Information',
                              style: MindWellTypography.sectionSubtitle(
                                color: MindWellColors.darkGray,
                              ).copyWith(fontSize: 20),
                            ),
                            const SizedBox(height: 16),

                            // Bio Field
                            KeyedSubtree(
                              key: _fieldKeys['bio'],
                              child: InputCard(
                                child: TextFormField(
                                  controller: _bioController,
                                  focusNode: _bioFocusNode,
                                  maxLines: 4,
                                  decoration: InputDecoration(
                                    labelText: 'Bio (Optional)',
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.all(16),
                                    labelStyle: MindWellTypography.body(
                                      color: MindWellColors.darkGray,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Location Field
                            KeyedSubtree(
                              key: _fieldKeys['location'],
                              child: InputCard(
                                child: TextFormField(
                                  controller: _locationController,
                                  focusNode: _locationFocusNode,
                                  decoration: InputDecoration(
                                    labelText: 'Location (Optional)',
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.all(16),
                                    labelStyle: MindWellTypography.body(
                                      color: MindWellColors.darkGray,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.location_on,
                                      color: MindWellColors.darkGray,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Gender Field
                            KeyedSubtree(
                              key: _fieldKeys['gender'],
                              child: InputCard(
                                child: TextFormField(
                                  controller: _genderController,
                                  focusNode: _genderFocusNode,
                                  decoration: InputDecoration(
                                    labelText: 'Gender (Optional)',
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.all(16),
                                    labelStyle: MindWellTypography.body(
                                      color: MindWellColors.darkGray,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.wc,
                                      color: MindWellColors.darkGray,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Date of Birth Field
                            KeyedSubtree(
                              key: _fieldKeys['dob'],
                              child: InputCard(
                                child: TextFormField(
                                  controller: _dobController,
                                  focusNode: _dobFocusNode,
                                  readOnly: true,
                                  onTap: _pickDateOfBirth,
                                  decoration: InputDecoration(
                                    labelText: 'Date of Birth (Optional)',
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.all(16),
                                    labelStyle: MindWellTypography.body(
                                      color: MindWellColors.darkGray,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.cake,
                                      color: MindWellColors.darkGray,
                                    ),
                                    hintText: 'YYYY-MM-DD',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Preferences Section
                            Text(
                              'Preferences',
                              style: MindWellTypography.sectionSubtitle(
                                color: MindWellColors.darkGray,
                              ).copyWith(fontSize: 20),
                            ),
                            const SizedBox(height: 16),

                            // Dark Mode Toggle
                            _buildPreferenceCard(
                              icon: Icons.dark_mode,
                              title: 'Dark Mode',
                              value: _darkMode,
                              onChanged: (value) {
                                setState(() {
                                  _darkMode = value;
                                  _hasChanges = true;
                                  _missingFields = _computeMissingFields();
                                });
                              },
                            ),
                            const SizedBox(height: 12),

                            // Notifications Toggle
                            _buildPreferenceCard(
                              icon: Icons.notifications,
                              title: 'Enable Notifications',
                              value: _darkNotifications,
                              onChanged: (value) {
                                setState(() {
                                  _darkNotifications = value;
                                  _hasChanges = true;
                                  _missingFields = _computeMissingFields();
                                });
                              },
                            ),
                            const SizedBox(height: 24),

                            // Action Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      if (await _showUnsavedWarning()) {
                                        if (mounted)
                                          Navigator.of(context).pop();
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      side: const BorderSide(
                                        color: MindWellColors.darkGray,
                                      ),
                                    ),
                                    child: Text(
                                      'Cancel',
                                      style: MindWellTypography.button(
                                        color: MindWellColors.darkGray,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _isSubmitting
                                        ? null
                                        : _handleSubmit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          MindWellColors.lightGreen,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                    ),
                                    child: _isSubmitting
                                        ? SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                            ),
                                          )
                                        : Text(
                                            'Save Changes',
                                            style: MindWellTypography.button(
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                    // Offline queue panel at bottom
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: OfflineQueuePanel(),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildManualCompletionCard() {
    return InputCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit_note, color: MindWellColors.lightGreen),
                const SizedBox(width: 8),
                Text(
                  'Complete Your Profile',
                  style: MindWellTypography.cardTitle(
                    color: MindWellColors.darkGray,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'We found a few missing details. Tap a tag to jump or use quick fill to update them manually.',
              style: MindWellTypography.body(
                color: Colors.grey.shade600,
              ).copyWith(fontSize: 12),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _missingFields
                  .map(
                    (field) => ActionChip(
                      avatar: Icon(
                        field.icon,
                        size: 16,
                        color: MindWellColors.darkGray,
                      ),
                      label: Text(field.label),
                      onPressed: () async => _scrollToField(field.id),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openManualFillSheet,
              icon: const Icon(Icons.playlist_add_check),
              label: const Text('Quick Fill Missing Fields'),
              style: OutlinedButton.styleFrom(
                foregroundColor: MindWellColors.lightGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build profile completeness card
  Widget _buildCompletenessCard(AsyncValue<int> completenessAsync) {
    return InputCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Profile Completeness',
                  style: MindWellTypography.cardTitle(
                    color: MindWellColors.darkGray,
                  ),
                ),
                completenessAsync.when(
                  loading: () => const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (_, __) => const Text('Error'),
                  data: (completeness) => Text(
                    '$completeness%',
                    style: MindWellTypography.button(
                      color: MindWellColors.lightGreen,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            completenessAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const LinearProgressIndicator(),
              data: (completeness) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: completeness / 100,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    MindWellColors.lightGreen,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Fill in your profile to unlock personalized features',
              style: MindWellTypography.body(
                color: Colors.grey.shade600,
              ).copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  /// Build preference toggle card
  Widget _buildPreferenceCard({
    required IconData icon,
    required String title,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return InputCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: MindWellColors.darkGray, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: MindWellTypography.body(color: MindWellColors.darkGray),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: MindWellColors.lightGreen,
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualFillSheet extends StatefulWidget {
  const _ManualFillSheet({
    required this.missingFields,
    required this.phoneController,
    required this.bioController,
    required this.locationController,
    required this.genderController,
    required this.dobController,
    required this.onPickDob,
  });

  final List<_ManualFieldDescriptor> missingFields;
  final TextEditingController phoneController;
  final TextEditingController bioController;
  final TextEditingController locationController;
  final TextEditingController genderController;
  final TextEditingController dobController;
  final Future<void> Function() onPickDob;

  @override
  State<_ManualFillSheet> createState() => _ManualFillSheetState();
}

class _ManualFillSheetState extends State<_ManualFillSheet> {
  @override
  Widget build(BuildContext context) {
    final helperStyle = MindWellTypography.body(
      color: Colors.grey.shade600,
    ).copyWith(fontSize: 12);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Quick Fill Missing Fields',
              style: MindWellTypography.sectionSubtitle(
                color: MindWellColors.darkGray,
              ).copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Update the essentials here. Your changes will appear in the profile form immediately.',
              style: MindWellTypography.body(
                color: Colors.grey.shade600,
              ).copyWith(fontSize: 12),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: widget.missingFields
                      .map(
                        (field) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildField(field, helperStyle),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: MindWellColors.lightGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(_ManualFieldDescriptor descriptor, TextStyle helperStyle) {
    switch (descriptor.id) {
      case 'phone':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              descriptor.label,
              style: MindWellTypography.body(color: MindWellColors.darkGray),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: widget.phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
                hintText: '+1 (555) 000-0000',
              ),
            ),
            const SizedBox(height: 6),
            Text(descriptor.helper, style: helperStyle),
          ],
        );
      case 'location':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              descriptor.label,
              style: MindWellTypography.body(color: MindWellColors.darkGray),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: widget.locationController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
                hintText: 'City, Country',
              ),
            ),
            const SizedBox(height: 6),
            Text(descriptor.helper, style: helperStyle),
          ],
        );
      case 'gender':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              descriptor.label,
              style: MindWellTypography.body(color: MindWellColors.darkGray),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: widget.genderController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.wc_outlined),
                border: OutlineInputBorder(),
                hintText: 'e.g. Female, Male, Non-binary',
              ),
            ),
            const SizedBox(height: 6),
            Text(descriptor.helper, style: helperStyle),
          ],
        );
      case 'dob':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              descriptor.label,
              style: MindWellTypography.body(color: MindWellColors.darkGray),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: widget.dobController,
              readOnly: true,
              onTap: widget.onPickDob,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.cake_outlined),
                border: OutlineInputBorder(),
                hintText: 'Select date',
              ),
            ),
            const SizedBox(height: 6),
            Text(descriptor.helper, style: helperStyle),
          ],
        );
      case 'bio':
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              descriptor.label,
              style: MindWellTypography.body(color: MindWellColors.darkGray),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: widget.bioController,
              maxLines: 4,
              decoration: const InputDecoration(
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
                hintText: 'Share a short introduction about yourself.',
              ),
            ),
            const SizedBox(height: 6),
            Text(descriptor.helper, style: helperStyle),
          ],
        );
    }
  }
}

class _ManualFieldDescriptor {
  const _ManualFieldDescriptor({
    required this.id,
    required this.label,
    required this.icon,
    required this.helper,
  });

  final String id;
  final String label;
  final IconData icon;
  final String helper;
}
