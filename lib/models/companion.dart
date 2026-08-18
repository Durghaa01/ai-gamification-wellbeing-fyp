import 'package:flutter/material.dart';

import '../models/assessment.dart' show AssessmentMessage, AgentRole;

/// 预设人格
enum CompanionPersona { listener, coach, planner, cheerleader }

@immutable
class Companion {
  final String id;
  final String name;
  final CompanionPersona persona;
  final String description;
  final IconData icon;
  final String tagline;
  final String systemPrompt;
  final Color primaryColor;
  final Color secondaryColor;
  final LinearGradient gradient;
  final List<String> quickPrompts;

  const Companion({
    required this.id,
    required this.name,
    required this.persona,
    required this.description,
    required this.icon,
    required this.tagline,
    required this.systemPrompt,
    required this.primaryColor,
    required this.secondaryColor,
    required this.gradient,
    required this.quickPrompts,
  });
}

/// 会话状态
class CompanionState {
  CompanionState({required this.current});
  Companion current;
  final List<AssessmentMessage> messages = [];
}
