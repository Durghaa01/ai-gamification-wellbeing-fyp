import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_mhproj/models/companion.dart';
import 'package:flutter_application_mhproj/models/models.dart';
import 'package:flutter_application_mhproj/models/message_send_result.dart';
import 'package:flutter_application_mhproj/models/assessment.dart';
import 'package:flutter_application_mhproj/ui/elements/responsive_page_scaffold.dart';
import 'package:flutter_application_mhproj/core/routes/app_routes.dart';
import 'package:flutter_application_mhproj/core/providers/app_providers.dart';

import '../application/companion_controller.dart';
import '../application/garden_controller.dart';

// Extracted Widgets
import 'widgets/companion_header.dart';
import 'widgets/chat_input_area.dart';
import 'widgets/breathing_practice_page.dart';
import 'widgets/sticker_rail.dart';
import 'widgets/garden_overlay.dart';
import 'widgets/quick_actions_carousel.dart';
import 'widgets/guest_banner.dart';
import 'widgets/companion_chat_area.dart';

class CompanionsPage extends ConsumerStatefulWidget {
  const CompanionsPage({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.isRegistered,
    this.sessionKey,
    this.userRole,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final bool isRegistered;
  final String? sessionKey;
  final Role? userRole;

  @override
  ConsumerState<CompanionsPage> createState() => _CompanionsPageState();
}

class _CompanionsPageState extends ConsumerState<CompanionsPage>
    with SingleTickerProviderStateMixin {
  static const int _guestMessageCap = 5;

  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  late CompanionSessionConfig _sessionConfig;

  // Typing & UI State
  Timer? _typingDecayTimer;
  double _typingIntensity = 0.0;
  bool _guestReminderShown = false;

  // Static Data
  static const List<String> _gentleChallenges = <String>[
    'Take a photo of something that makes you smile.',
    'Drink a glass of water mindfully.',
    'Stretch your arms up and take a deep breath.',
    'Write down one thing you are grateful for.',
    'Send a kind message to a friend.',
  ];

  @override
  void initState() {
    super.initState();
    _sessionConfig = CompanionSessionConfig(
      userId: widget.isRegistered ? (widget.sessionKey ?? 'local_user') : null,
      isGuest: !widget.isRegistered,
      messageLimit: widget.isRegistered ? null : _guestMessageCap,
      persistHistory: widget.isRegistered,
      userRole: widget.userRole ?? Role.user,
    );

    _input.addListener(_onTyping);

    // Initial scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToBottom();
      if (_sessionConfig.isGuest) {
        _showGuidedGuestIntro();
      }
    });
  }

  @override
  void dispose() {
    _input.removeListener(_onTyping);
    _input.dispose();
    _scroll.dispose();
    _typingDecayTimer?.cancel();
    super.dispose();
  }

  void _onTyping() {
    if (_input.text.isNotEmpty) {
      setState(() {
        _typingIntensity = math.min(1.0, _typingIntensity + 0.05);
      });
      _resetTypingDecay();
    }
  }

  void _resetTypingDecay() {
    _typingDecayTimer?.cancel();
    _typingDecayTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) return;
      setState(() {
        _typingIntensity = math.max(0.0, _typingIntensity - 0.02);
      });
      if (_typingIntensity <= 0) {
        t.cancel();
      }
    });
  }

  void _jumpToBottom() {
    if (_scroll.hasClients) {
      // Small delay to allow list to render new items
      Future<void>.delayed(const Duration(milliseconds: 100), () {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _send(String text) async {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final viewState = ref.read(companionControllerProvider(_sessionConfig));
    if (viewState.isLoading && viewState.streamingMessage != null) {
      return;
    }
    final CompanionController controller = ref.read(
      companionControllerProvider(_sessionConfig).notifier,
    );

    // Use streaming for better UX
    final MessageSendResult result = await controller.sendStream(trimmed);

    if (!mounted) {
      return;
    }

    if (result.success) {
      _input.clear();
      _jumpToBottom();

      // Award garden points
      ref
          .read(gardenControllerProvider.notifier)
          .addLeaves(1, sticker: 'Shared · +1 leaf');
      ref.read(gardenControllerProvider.notifier).addGrowth(1);
    } else if (_sessionConfig.isGuest &&
        result.error == 'Guest message limit reached') {
      _showGuestLimitDialog();
    } else if (result.canRetry) {
      _showRetrySnackbar(result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Failed to send message'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showRetrySnackbar(MessageSendResult result) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Message failed to send.'),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () {
            _send(result.error ?? '');
          },
        ),
      ),
    );
  }

  void _showGuestLimitDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Guest Preview Limit'),
        content: const Text(
          'You have reached the message cap for guest mode.\n\nCreate an account to unlock unlimited chat, saved history, and better recommendations.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Browsing'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _goToSignup();
            },
            child: const Text('Sign Up'),
          ),
        ],
      ),
    );
  }

  void _showGuidedGuestIntro() {
    if (!_guestReminderShown) {
      setState(() => _guestReminderShown = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Welcome! Try saying "Hello" to start.')),
      );
    }
  }

  void _openSessionManager() {
    final userId = _sessionConfig.userId;
    if (userId == null || userId.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session management coming soon')),
    );
  }

  Future<bool> _openBreathingPage(Companion companion) async {
    HapticFeedback.selectionClick();
    final bool? completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => BreathingPracticePage(companion: companion),
      ),
    );
    if (completed == true && mounted) {
      ref
          .read(gardenControllerProvider.notifier)
          .addLeaves(2, sticker: 'Breath complete');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks for taking a mindful breath.')),
      );
    }
    return completed ?? false;
  }

  Future<void> _openGardenPage(
    Companion companion,
    String gentleChallenge,
  ) async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) {
          // We need to pass the state from the provider to the overlay
          // Since GardenOverlay is a StatefulWidget that initializes state in initState,
          // we should ideally refactor it to be reactive.
          // But for now, we can wrap it in a Consumer to pass the latest values.
          return Consumer(
            builder: (context, ref, _) {
              final gardenState = ref.watch(gardenControllerProvider);
              final gardenController = ref.read(
                gardenControllerProvider.notifier,
              );

              return GardenOverlay(
                companion: companion,
                leaves: gardenState.leaves,
                stickers: gardenState.stickers,
                challengeCopy: gentleChallenge,
                challengeCompleted: gardenController.isChallengeCompleted,
                onCompleteChallenge: () async {
                  await Future.delayed(const Duration(milliseconds: 500));
                  gardenController.completeChallenge();
                  return true;
                },
                onStartBreathing: () => _openBreathingPage(companion),
                plantGrowth: gardenState.plantGrowth,
                unlockedPlants: gardenState.unlockedPlants,
                activePlantId: gardenState.activePlantId,
                onPlantSelect: (plantId) {
                  gardenController.setActivePlant(plantId);
                },
                onPlantGrowth: (delta) {
                  gardenController.addGrowth(delta);
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showPromptLibrary(Companion companion) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: QuickActionsCarousel(
          companion: companion,
          onPromptSelected: (prompt) {
            Navigator.pop(context);
            _prefillText(prompt);
          },
          onTemplateSelected: (prompt) {
            Navigator.pop(context);
            _prefillText(prompt);
          },
        ),
      ),
    );
  }

  void _switchCompanion(Companion persona) {
    ref
        .read(companionControllerProvider(_sessionConfig).notifier)
        .switchCompanion(persona);
  }

  void _prefillText(String text) {
    _input.text = text;
    _input.selection = TextSelection.fromPosition(
      TextPosition(offset: _input.text.length),
    );
  }

  int? _remainingMessages(CompanionViewState state) {
    final limit = _sessionConfig.messageLimit;
    if (limit == null) return null;
    final sent = state.messages
        .where((m) => m.role == AgentRole.user)
        .length;
    final remaining = limit - sent;
    return remaining < 0 ? 0 : remaining;
  }

  void _goToSignup() {
    Navigator.of(context).pushNamed(AppRoutes.roleSelection);
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final viewState = ref.watch(companionControllerProvider(_sessionConfig));
    final gardenState = ref.watch(gardenControllerProvider);
    final companion = viewState.current;
    final String gentleChallenge =
        _gentleChallenges[DateTime.now().day % _gentleChallenges.length];
    final remaining = _remainingMessages(viewState);

    return MindWellResponsiveScaffold(
      appBar: CompanionHeader(
        isDarkMode: widget.isDarkMode,
        onThemeChanged: widget.onThemeChanged,
        isGuest: _sessionConfig.isGuest,
        onOpenSessionManager: _openSessionManager,
      ),
      scrollable: false,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: <Widget>[
          if (!config.remoteBackendEnabled)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off, color: Colors.amber),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Offline companion mode: responses use the local model and may be simpler.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.amber.shade900,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_sessionConfig.isGuest)
            GuestBanner(messageLimit: _guestMessageCap, companion: companion),
          CompanionChatArea(
            companion: companion,
            typingIntensity: _typingIntensity,
            scrollController: _scroll,
            viewState: viewState,
            isDarkMode: widget.isDarkMode,
            onBreathTap: () => _openBreathingPage(companion),
            onTemplateTap: _prefillText,
            onSwitchPersona: _switchCompanion,
          ),
          if (gardenState.stickers.isNotEmpty)
            Flexible(
              flex: 1,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: StickerRail(
                  stickers: gardenState.stickers,
                  companion: companion,
                ),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_sessionConfig.isGuest && remaining != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blueGrey.shade100),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '$remaining messages left in preview',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.blueGrey.shade700,
                                ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _goToSignup,
                            child: const Text('Unlock unlimited'),
                          ),
                        ],
                      ),
                    ),
                  ChatInputArea(
                    controller: _input,
                    isLoading: viewState.isLoading,
                    companion: companion,
                    onSend: _send,
                    onPromptLibraryTap: () => _showPromptLibrary(companion),
                    onBreathingTap: () => _openBreathingPage(companion),
                    onGardenTap: () => _openGardenPage(companion, gentleChallenge),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
