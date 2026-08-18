import 'package:flutter/material.dart';
import 'package:flutter_application_mhproj/models/assessment.dart';
import 'package:flutter_application_mhproj/models/companion.dart';
import 'package:flutter_application_mhproj/widgets/streaming_chat_bubble.dart';
import 'package:flutter_application_mhproj/features/companions/application/companion_controller.dart';

class MessageListView extends StatelessWidget {
  const MessageListView({
    super.key,
    required this.scrollController,
    required this.viewState,
    required this.companion,
    required this.isDarkMode,
    required this.onBreathTap,
    required this.onTemplateTap,
    required this.onSwitchPersona,
    required this.presets,
  });

  final ScrollController scrollController;
  final CompanionViewState viewState;
  final Companion companion;
  final bool isDarkMode;
  final VoidCallback onBreathTap;
  final ValueChanged<String> onTemplateTap;
  final ValueChanged<Companion> onSwitchPersona;
  final List<Companion> presets;

  @override
  Widget build(BuildContext context) {
    final List<Widget> items = <Widget>[
      PersonaIntroMessage(
        companion: companion,
        presets: presets,
        onSwitch: onSwitchPersona,
        onTemplateTap: onTemplateTap,
      ),
    ];

    if (viewState.messages.isEmpty) {
      items.add(EmptyHintCard(onBreathTap: onBreathTap));
    }

    for (final AssessmentMessage message in viewState.messages) {
      items.add(CompanionMessageBubble(message: message, companion: companion));
    }

    if (viewState.streamingMessage != null) {
      items.add(
        StreamingChatBubble(
          message: viewState.streamingMessage!,
          isDarkMode: isDarkMode,
          companionName: companion.name,
        ),
      );
    }

    if (viewState.isLoading && viewState.streamingMessage == null) {
      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: GentleTypingIndicator(companion: companion),
        ),
      );
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 24, 68, 28),
      children: items,
    );
  }
}

class PersonaIntroMessage extends StatelessWidget {
  const PersonaIntroMessage({
    super.key,
    required this.companion,
    required this.presets,
    required this.onSwitch,
    required this.onTemplateTap,
  });

  final Companion companion;
  final List<Companion> presets;
  final ValueChanged<Companion> onSwitch;
  final ValueChanged<String> onTemplateTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: companion.secondaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.chat_bubble_outline, color: companion.secondaryColor),
              const SizedBox(width: 8),
              Text(
                'Hello, I am your companion team.',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'We have four styles. Choose how you want to be supported; you can switch anytime.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presets.map((persona) {
              final bool isSelected = persona.id == companion.id;
              return ChoiceChip(
                label: Text(persona.name),
                avatar: Icon(
                  persona.icon,
                  size: 18,
                  color: isSelected ? Colors.white : persona.primaryColor,
                ),
                selected: isSelected,
                showCheckmark: false,
                selectedColor: persona.primaryColor.withValues(alpha: 0.9),
                backgroundColor: theme.cardColor,
                labelStyle: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : theme.textTheme.bodyMedium?.color,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide(
                  color: isSelected
                      ? persona.primaryColor.withValues(alpha: 0.8)
                      : theme.dividerColor.withValues(alpha: 0.4),
                ),
                onSelected: (_) => onSwitch(persona),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => onTemplateTap(
              'Can you switch your tone or style to what I need right now?',
            ),
            child: const Text('Ask for a different vibe'),
          ),
        ],
      ),
    );
  }
}

class EmptyHintCard extends StatelessWidget {
  const EmptyHintCard({super.key, required this.onBreathTap});

  final VoidCallback onBreathTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.spa_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tell me how you are feeling, or tap to start a 1-min breathing reset.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          TextButton.icon(
            onPressed: onBreathTap,
            icon: const Icon(Icons.self_improvement),
            label: const Text('Breath'),
          ),
        ],
      ),
    );
  }
}

class CompanionMessageBubble extends StatelessWidget {
  const CompanionMessageBubble({
    super.key,
    required this.message,
    required this.companion,
  });

  final AssessmentMessage message;
  final Companion companion;

  @override
  Widget build(BuildContext context) {
    final bool isUser = message.role == AgentRole.user;
    final Alignment alignment = isUser
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final Color bubbleColor = isUser
        ? companion.primaryColor.withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.08);
    final Color effectiveTextColor = isUser
        ? Colors.white
        : Colors.white.withValues(alpha: 0.9);
    final String label = isUser ? 'You' : companion.name;

    return Align(
      alignment: alignment,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isUser
                ? Colors.white.withValues(alpha: 0.18)
                : companion.secondaryColor.withValues(alpha: 0.25),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: companion.secondaryColor.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.75),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message.text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: effectiveTextColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _formatTimestamp(message.ts),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final String hours = timestamp.hour.toString().padLeft(2, '0');
    final String minutes = timestamp.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }
}

class GentleTypingIndicator extends StatelessWidget {
  const GentleTypingIndicator({super.key, required this.companion});

  final Companion companion;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          margin: const EdgeInsets.only(top: 6, bottom: 2, right: 64),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: companion.secondaryColor.withValues(alpha: 0.3),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: companion.primaryColor.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.spa_outlined,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 8),
              const Text(
                'Finding a caring reply…',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
