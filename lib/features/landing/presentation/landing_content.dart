import 'package:flutter/material.dart';

class MindWellCardInfo {
  const MindWellCardInfo({
    required this.title,
    required this.description,
    required this.imageUrl,
  });

  final String title;
  final String description;
  final String imageUrl;
}

class MindWellToolkitInfo {
  const MindWellToolkitInfo({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}

class MindWellLandingContent {
  const MindWellLandingContent._();

  static const heroImageUrl =
      'https://images.unsplash.com/photo-1506126613408-eca07ce68773?auto=format&fit=crop&w=1920&q=80';

  static const methodImageUrl =
      'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?auto=format&fit=crop&w=1400&q=80';

  static const expertsImageUrl =
      'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=1400&q=80';

  static const List<MindWellCardInfo> sanctuaries = [
    MindWellCardInfo(
      title: 'The Lake House, Alps',
      description:
          'Nestled by a serene alpine lake, offering stunning views and profound tranquility.',
      imageUrl:
          'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1000&q=80',
    ),
    MindWellCardInfo(
      title: 'The Coast, Sylt',
      description:
          "Experience the invigorating power of the North Sea on Germany's most beautiful island.",
      imageUrl:
          'https://images.unsplash.com/photo-1505731355857-bb81e421d7af?auto=format&fit=crop&w=1000&q=80',
    ),
    MindWellCardInfo(
      title: 'The Urban Retreat, London',
      description:
          'A discreet oasis in the heart of Mayfair, for ongoing support and clarity.',
      imageUrl:
          'https://images.unsplash.com/photo-1528909514045-2fa4ac7a08ba?auto=format&fit=crop&w=1000&q=80',
    ),
  ];

  static const List<MindWellCardInfo> programmes = [
    MindWellCardInfo(
      title: 'Stress & Burnout Recovery',
      description:
          'Deep regenerative programs to restore your energy and build lasting resilience.',
      imageUrl:
          'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1000&q=80',
    ),
    MindWellCardInfo(
      title: 'Anxiety & Mood Balance',
      description:
          'Scientifically-backed therapies to regain control and find emotional equilibrium.',
      imageUrl:
          'https://images.unsplash.com/photo-1526857240824-92be52581d1b?auto=format&fit=crop&w=1000&q=80',
    ),
    MindWellCardInfo(
      title: 'Mindfulness & Performance',
      description:
          'Tailored plans to optimize focus, clarity, and cognitive performance.',
      imageUrl:
          'https://images.unsplash.com/photo-1528715471579-d1bcf0ba5e83?auto=format&fit=crop&w=1000&q=80',
    ),
  ];

  static const List<MindWellToolkitInfo> toolkit = [
    MindWellToolkitInfo(
      title: 'AI Chatbot',
      description: 'Instant, confidential support & guidance.',
      icon: Icons.chat_bubble_rounded,
    ),
    MindWellToolkitInfo(
      title: 'Self-Assessment',
      description: 'Understand your needs with our guided tools.',
      icon: Icons.assignment_turned_in_rounded,
    ),
    MindWellToolkitInfo(
      title: 'Private Journal',
      description: 'A secure space to reflect and track your journey.',
      icon: Icons.edit_note_rounded,
    ),
    MindWellToolkitInfo(
      title: 'Resource Library',
      description: 'Expert-curated articles, audio, and exercises.',
      icon: Icons.menu_book_rounded,
    ),
    MindWellToolkitInfo(
      title: 'Appointments',
      description: 'Manage your sessions with our experts.',
      icon: Icons.calendar_today_rounded,
    ),
    MindWellToolkitInfo(
      title: 'Wellness Trends',
      description: 'Visualize your progress and mood patterns.',
      icon: Icons.insights_rounded,
    ),
  ];
}
