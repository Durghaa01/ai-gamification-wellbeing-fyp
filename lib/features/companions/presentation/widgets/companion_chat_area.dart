import 'package:flutter/material.dart';
import 'package:flutter_application_mhproj/features/companions/application/companion_controller.dart';
import 'package:flutter_application_mhproj/models/companion.dart';

import 'message_list_view.dart';
import 'persona_backdrop.dart';
import 'walking_pet.dart';

class CompanionChatArea extends StatelessWidget {
  const CompanionChatArea({
    super.key,
    required this.companion,
    required this.typingIntensity,
    required this.scrollController,
    required this.viewState,
    required this.isDarkMode,
    required this.onBreathTap,
    required this.onTemplateTap,
    required this.onSwitchPersona,
  });

  final Companion companion;
  final double typingIntensity;
  final ScrollController scrollController;
  final CompanionViewState viewState;
  final bool isDarkMode;
  final VoidCallback onBreathTap;
  final ValueChanged<String> onTemplateTap;
  final ValueChanged<Companion> onSwitchPersona;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      flex: 6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: companion.gradient,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: companion.primaryColor.withValues(alpha: 0.08),
                blurRadius: 28,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: PersonaBackdrop(
                    companion: companion,
                    typingIntensity: typingIntensity,
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(
                        alpha: isDarkMode ? 0.38 : 0.12,
                      ),
                    ),
                  ),
                ),
                // Walking Pet at the top
                const Positioned(
                  top: 8,
                  left: 12,
                  right: 12,
                  height: 60,
                  child: IgnorePointer(
                    ignoring: false, // Allow interaction with pet
                    child: WalkingPet(),
                  ),
                ),
                Positioned.fill(
                  top: 60, // Push chat down to avoid pet
                  child: MessageListView(
                    scrollController: scrollController,
                    viewState: viewState,
                    companion: companion,
                    isDarkMode: isDarkMode,
                    onBreathTap: onBreathTap,
                    onTemplateTap: onTemplateTap,
                    onSwitchPersona: onSwitchPersona,
                    presets: viewState.presets,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
