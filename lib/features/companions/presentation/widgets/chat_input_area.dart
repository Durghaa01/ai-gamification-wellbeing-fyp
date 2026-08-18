import 'package:flutter/material.dart';
import 'package:flutter_application_mhproj/models/companion.dart';

class ChatInputArea extends StatelessWidget {
  const ChatInputArea({
    super.key,
    required this.controller,
    required this.isLoading,
    required this.companion,
    required this.onSend,
    required this.onPromptLibraryTap,
    required this.onBreathingTap,
    required this.onGardenTap,
  });

  final TextEditingController controller;
  final bool isLoading;
  final Companion companion;
  final ValueChanged<String> onSend;
  final VoidCallback onPromptLibraryTap;
  final VoidCallback onBreathingTap;
  final VoidCallback onGardenTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: companion.secondaryColor.withValues(alpha: 0.3),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: companion.primaryColor.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Tooltip(
            message: 'Prompt ideas',
            child: IconButton(
              onPressed: isLoading ? null : onPromptLibraryTap,
              icon: Icon(Icons.auto_awesome, color: companion.secondaryColor),
            ),
          ),
          IconButton(
            tooltip: 'Breathing guide',
            onPressed: isLoading ? null : onBreathingTap,
            icon: Icon(Icons.self_improvement, color: companion.secondaryColor),
          ),
          IconButton(
            tooltip: 'Emotion Garden',
            onPressed: isLoading ? null : onGardenTap,
            icon: Icon(
              Icons.local_florist_outlined,
              color: companion.secondaryColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !isLoading,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(controller.text),
              cursorColor: companion.secondaryColor,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'How are you feeling today?',
                isCollapsed: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 44,
            child: FilledButton(
              onPressed: isLoading ? null : () => onSend(controller.text),
              style: FilledButton.styleFrom(
                backgroundColor: companion.primaryColor,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ),
        ],
      ),
    );
  }
}
