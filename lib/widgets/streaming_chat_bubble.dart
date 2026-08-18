import 'package:flutter/material.dart';
import 'package:flutter_application_mhproj/design_system/tokens/color_tokens.dart';
import 'package:flutter_application_mhproj/design_system/tokens/typography.dart';
import 'package:flutter_application_mhproj/models/streaming_message.dart';

/// Chat bubble that displays a streaming message with typewriter effect
class StreamingChatBubble extends StatefulWidget {
  const StreamingChatBubble({
    super.key,
    required this.message,
    required this.isDarkMode,
    this.companionName = 'Assistant',
  });

  final StreamingMessage message;
  final bool isDarkMode;
  final String companionName;

  @override
  State<StreamingChatBubble> createState() => _StreamingChatBubbleState();
}

class _StreamingChatBubbleState extends State<StreamingChatBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _cursorController;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isDarkMode
        ? MindWellColors.darkGray.withValues(alpha: 0.3)
        : MindWellColors.lightGreen.withValues(alpha: 0.15);

    final textColor = widget.isDarkMode
        ? MindWellColors.cream
        : MindWellColors.darkGray;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: MindWellColors.accentCyan.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Companion name
            Text(
              widget.companionName,
              style: MindWellTypography.button(color: MindWellColors.accentCyan).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            // Streaming text with cursor
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    widget.message.text.isEmpty ? ' ' : widget.message.text,
                    style: MindWellTypography.body(color: textColor),
                  ),
                ),
                if (!widget.message.isComplete)
                  FadeTransition(
                    opacity: _cursorController,
                    child: Container(
                      width: 8,
                      height: 16,
                      margin: const EdgeInsets.only(left: 2, top: 4),
                      decoration: BoxDecoration(
                        color: MindWellColors.accentCyan,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
            // Error indicator
            if (widget.message.error != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 16,
                    color: MindWellColors.accentPink,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.message.error!,
                      style: MindWellTypography.body(color: MindWellColors.accentPink).copyWith(
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            // Loading indicator (waiting for first chunk)
            if (widget.message.text.isEmpty && !widget.message.isComplete && widget.message.error == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          MindWellColors.accentCyan,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Thinking...',
                      style: MindWellTypography.body(color: MindWellColors.accentCyan.withValues(alpha: 0.7)).copyWith(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
