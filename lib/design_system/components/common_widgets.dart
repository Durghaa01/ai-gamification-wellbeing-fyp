import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';
import '../tokens/typography.dart';

class InputCard extends StatelessWidget {
  const InputCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.icon,
    required this.controller,
  });
  final String label;
  final IconData icon;
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: MindWellTypography.body(color: MindWellColors.darkGray),
        prefixIcon: Icon(icon, color: MindWellColors.darkGray),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: MindWellColors.darkGray,
            width: 0.6,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: MindWellColors.lightGreen,
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

class RoleCard extends StatelessWidget {
  const RoleCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 220,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 18,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: MindWellColors.lightGreen.withOpacity(0.28),
              child: Icon(icon, size: 36, color: MindWellColors.darkGray),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: MindWellTypography.sectionSubtitle(
                color: MindWellColors.darkGray,
              ).copyWith(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class FeatureButton extends StatelessWidget {
  const FeatureButton({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: MindWellColors.lightGreen.withOpacity(0.3),
              child: Icon(icon, color: MindWellColors.darkGray, size: 26),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                title,
                style: MindWellTypography.body(
                  color: MindWellColors.darkGray,
                ).copyWith(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.chevron_right, color: MindWellColors.darkGray),
          ],
        ),
      ),
    );
  }
}

class CopyrightBar extends StatelessWidget {
  const CopyrightBar({super.key});
  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: MindWellColors.darkGray,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '© 2025 MindWell Clinic',
              style: MindWellTypography.body(
                color: MindWellColors.cream,
              ).copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
