import 'dart:math'; 
import 'package:collection/collection.dart';

class DynamicContent {
  final String title;
  final String description;
  final String contentUrl;
  final String type;
  final double aiConfidence;
  final String category;
  final String? id; // Resource ID from database
  final String? mood; // Target mood
  final String techniqueUsed; // Which AI technique recommended this
  final String explanation; // Explanation for recommendation

  const DynamicContent({
    required this.title,
    required this.description,
    required this.contentUrl,
    required this.type,
    required this.aiConfidence,
    required this.category,
    this.id,
    this.mood,
    this.techniqueUsed = 'content_based', // Default value
    this.explanation = 'AI recommended', // Default value
  });
}

class GenerativeAIEngine {
  final Map<String, Map<String, List<String>>> _moodContentTemplates = {
    'Stressed': {
      'Music': [
        'Calming {genre} for stress relief',
        'Soothing {instrument} melodies to calm anxiety',
        'Peaceful {theme} sounds for relaxation'
      ],
      'Exercise': [
        '{duration}-minute breathing exercise for stress',
        'Gentle {activity} for anxiety relief',
        'Mindful {practice} to release tension'
      ],
      'Article': [
        'Coping with Stress: {approach} techniques',
        'Managing Anxiety through {method}',
        'Stress Relief: {strategy} approaches'
      ],
      'Affirmation': [
        'Breathe. You are safe in this moment.',
        'This feeling is temporary. You are strong.',
        'Release the tension. Welcome peace.'
      ]
    },
    'Sad': {
      'Music': [
        'Upbeat {genre} to lift your spirits',
        'Motivational {theme} playlist for mood boost',
        'Happy {era} songs to bring joy'
      ],
      'Exercise': [
        'Energizing {activity} workout',
        'Fun {type} moves to increase happiness',
        'Joyful {practice} to uplift mood'
      ],
      'Article': [
        'Finding Joy in {aspect} of life',
        'Overcoming Sadness with {approach}',
        'Happiness Habits: {strategy}'
      ],
      'Affirmation': [
        'You are worthy of happiness and love.',
        'This moment will pass. Brighter days ahead.',
        'Your feelings are valid. You are strong.'
      ]
    },
    'Neutral': {
      'Music': [
        'Focus {genre} for productivity',
        'Balanced {instrument} for daily activities',
        'Mindful {theme} for concentration'
      ],
      'Exercise': [
        'Balanced {activity} for wellness',
        'Maintenance {practice} for consistency',
        'Sustainable {type} for daily routine'
      ],
      'Article': [
        'Maintaining Emotional Balance with {approach}',
        'Daily Wellness: {strategy} practices',
        'Consistent Self-Care: {method}'
      ],
      'Affirmation': [
        'You are balanced and centered today.',
        'Each moment is an opportunity for growth.',
        'You are exactly where you need to be.'
      ]
    }
  };

  final Map<String, List<String>> _contentVariations = {
    'genre': ['piano', 'ambient', 'lo-fi', 'classical', 'jazz', 'acoustic'],
    'instrument': ['piano', 'guitar', 'flute', 'strings', 'harp', 'nature'],
    'theme': ['nature', 'meditation', 'focus', 'sleep', 'mindfulness'],
    'duration': ['5', '10', '15', '20', '30'],
    'activity': ['yoga', 'stretching', 'breathing', 'walking', 'dance'],
    'practice': ['meditation', 'mindfulness', 'breathing', 'movement'],
    'approach': ['Mindfulness', 'Cognitive', 'Behavioral', 'Practical'],
    'method': ['Breathing', 'Meditation', 'Exercise', 'Journaling'],
    'strategy': ['Daily Habits', 'Mindful Practices', 'Quick Techniques'],
    'era': ['80s', '90s', '2000s', 'current', 'classic'],
    'type': ['dance', 'cardio', 'strength', 'flexibility'],
    'aspect': ['Small Things', 'Everyday Moments', 'Simple Pleasures']
  };

  List<DynamicContent> _generateContentBasedRecommendations({
    required String currentMood,
    required List<String> userLikedTitles,
    required Map<String, dynamic> userProfile,
    int limit = 3,
  }) {
    final recommendations = <DynamicContent>[];
    final preferredCategories = userProfile['preferredCategories'] ?? ['Music', 'Exercise'];
    
    for (final category in preferredCategories.take(2)) {
      final template = _getPersonalizedTemplate(currentMood, category, userLikedTitles);
      final content = _generateContentFromTemplate(template, currentMood, category, userProfile);
      recommendations.add(content);
    }
    
    return recommendations.take(limit).toList();
  }

  List<DynamicContent> _generateCollaborativeRecommendations({
    required String currentMood,
    required Map<String, dynamic> userBehavior,
    required Map<String, Map<String, dynamic>> similarUsersPatterns,
    int limit = 3,
  }) {
    final recommendations = <DynamicContent>[];
    
    final popularCategories = _analyzeCategoryPatterns(similarUsersPatterns, currentMood);
    final effectiveTemplates = _analyzeEffectiveTemplates(similarUsersPatterns, currentMood);
    
    for (final category in popularCategories.take(2)) {
      final template = effectiveTemplates[category] ?? _getRandomTemplate(currentMood, category);
      final content = _generateContentFromTemplate(template, currentMood, category, {
        'preferredCategories': popularCategories,
        'interactionHistory': userBehavior['recentInteractions'] ?? []
      });
      recommendations.add(content);
    }
    
    return recommendations.take(limit).toList();
  }

  List<DynamicContent> _generateKnowledgeBasedRecommendations({
    required String currentMood,
    required Map<String, dynamic> userContext,
    required Map<String, dynamic> userProfile,
    int limit = 3,
  }) {
    final recommendations = <DynamicContent>[];
    
    final Map<String, List<String>> moodPrinciples = {
      'Stressed': ['Grounding Techniques', 'Breathing Exercises', 'Progressive Relaxation'],
      'Sad': ['Behavioral Activation', 'Positive Psychology', 'Social Connection'],
      'Neutral': ['Preventive Care', 'Skill Building', 'Habit Formation']
    };
    
    final principles = moodPrinciples[currentMood] ?? ['Mindfulness', 'Self-Care', 'Wellness'];
    
    for (final principle in principles.take(2)) {
      final category = _mapPrincipleToCategory(principle);
      final template = _createPrincipleBasedTemplate(principle, currentMood);
      final content = _generateContentFromTemplate(template, currentMood, category, {
        ...userProfile,
        'principle': principle,
        'timeOfDay': userContext['timeOfDay'],
        'stressLevel': userContext['stressLevel']
      });
      recommendations.add(content);
    }
    
    return recommendations.take(limit).toList();
  }

  List<DynamicContent> generateUniqueRecommendations({
    required String currentMood,
    required String userId,
    required List<String> userLikedTitles,
    required Map<String, dynamic> userContext,
    required Map<String, dynamic> userProfile,
    required Map<String, Map<String, dynamic>> userBehaviorData,
    int totalLimit = 8,
  }) {
    print('🎨 GENERATIVE AI: Creating unique recommendations for user $userId');
    
    final similarUsersPatterns = _findSimilarUsersPatterns(userId, userBehaviorData);
    
    final contentBased = _generateContentBasedRecommendations(
      currentMood: currentMood,
      userLikedTitles: userLikedTitles,
      userProfile: userProfile,
      limit: 3,
    );

    final collaborative = _generateCollaborativeRecommendations(
      currentMood: currentMood,
      userBehavior: userProfile,
      similarUsersPatterns: similarUsersPatterns,
      limit: 3,
    );

    final knowledgeBased = _generateKnowledgeBasedRecommendations(
      currentMood: currentMood,
      userContext: userContext,
      userProfile: userProfile,
      limit: 3,
    );

    final allRecommendations = [...contentBased, ...collaborative, ...knowledgeBased];
    final uniqueRecommendations = <String, DynamicContent>{};
    
    for (final rec in allRecommendations) {
      final uniqueKey = '${rec.title}-${rec.category}-${rec.type}';
      if (!uniqueRecommendations.containsKey(uniqueKey)) {
        uniqueRecommendations[uniqueKey] = rec;
      }
    }

    final results = uniqueRecommendations.values.take(totalLimit).toList();
    
    print('✨ Generated ${results.length} UNIQUE recommendations for user ${userProfile['userId']}');
    
    return results;
  }

  // ... (all helper methods remain exactly the same)
  String _getPersonalizedTemplate(String mood, String category, List<String> likedTitles) {
    final userPreferences = _analyzeUserPreferences(likedTitles, category);
    final baseTemplates = _moodContentTemplates[mood]?[category] ?? ['${category} for ${mood} mood'];
    
    final random = Random();
    String selectedTemplate = baseTemplates[random.nextInt(baseTemplates.length)];
    
    if (userPreferences.isNotEmpty) {
      final preference = userPreferences[random.nextInt(userPreferences.length)];
      selectedTemplate = selectedTemplate.replaceFirst('{', '{$preference-');
    }
    
    return selectedTemplate;
  }

  DynamicContent _generateContentFromTemplate(
    String template, 
    String mood, 
    String category, 
    Map<String, dynamic> userProfile
  ) {
    final random = Random();
    
    String filledTemplate = template;
    filledTemplate = filledTemplate.replaceAllMapped(RegExp(r'\{(\w+)\}'), (match) {
      final key = match.group(1)!;
      final variations = _contentVariations[key] ?? [key];
      return variations[random.nextInt(variations.length)];
    });

    final title = _capitalize(filledTemplate);
    final description = _generateDescription(title, mood, category, userProfile);
    final contentUrl = _generateContentUrl(title, category, userProfile);
    final confidence = _calculateGenerativeConfidence(mood, category, userProfile);
    

    return DynamicContent(
      title: title,
      description: description,
      contentUrl: contentUrl,
      type: category.toLowerCase(),
      aiConfidence: confidence,
      category: category,
      id: 'gen_${DateTime.now().millisecondsSinceEpoch}',
      mood: mood,
      techniqueUsed: 'content_based',
      explanation: 'Generated based on your mood',
    );
  }

  String _generateDescription(String title, String mood, String category, Map<String, dynamic> userProfile) {
    final descriptions = {
      'Stressed': [
        'Specially designed to help you find calm and reduce anxiety.',
        'Perfect for when you need to unwind and release tension.',
        'A gentle approach to managing stress and finding inner peace.'
      ],
      'Sad': [
        'Created to uplift your spirits and bring positivity to your day.',
        'Designed to boost your mood and help you find joy again.',
        'A supportive resource for when you need emotional comfort.'
      ],
      'Neutral': [
        'Helps maintain your emotional balance and daily wellness.',
        'Supports your ongoing journey of self-care and growth.',
        'Perfect for maintaining consistency in your wellness routine.'
      ]
    };
    
    final moodDescs = descriptions[mood] ?? ['A helpful resource for your current mood.'];
    final random = Random();
    return moodDescs[random.nextInt(moodDescs.length)];
  }

  String _generateContentUrl(String title, String category, Map<String, dynamic> userProfile) {
    final encodedTitle = Uri.encodeComponent(title);
    
    switch (category) {
      case 'Music':
        return 'https://www.youtube.com/results?search_query=$encodedTitle+meditation+music';
      case 'Exercise':
        return 'https://www.youtube.com/results?search_query=$encodedTitle+guided+exercise';
      case 'Article':
        return 'https://www.google.com/search?q=$encodedTitle+mental+health+techniques';
      case 'Affirmation':
        return 'https://www.google.com/search?q=$encodedTitle+daily+affirmations';
      default:
        return 'https://www.google.com/search?q=$encodedTitle+mental+wellness';
    }
  }

  double _calculateGenerativeConfidence(String mood, String category, Map<String, dynamic> userProfile) {
    double confidence = 0.7;
    
    final moodCategoryAlignment = {
      'Stressed': {'Music': 0.9, 'Exercise': 0.8, 'Article': 0.7, 'Affirmation': 0.8},
      'Sad': {'Music': 0.8, 'Exercise': 0.7, 'Article': 0.8, 'Affirmation': 0.9},
      'Neutral': {'Music': 0.7, 'Exercise': 0.8, 'Article': 0.8, 'Affirmation': 0.7},
    };
    
    confidence += (moodCategoryAlignment[mood]?[category] ?? 0.7) * 0.3;
    
    return confidence.clamp(0.0, 1.0);
  }

  List<String> _analyzeUserPreferences(List<String> likedTitles, String category) {
    final preferences = <String>[];
    
    for (final title in likedTitles) {
      for (final variation in _contentVariations.keys) {
        if (title.toLowerCase().contains(variation)) {
          preferences.add(variation);
        }
      }
    }
    
    return preferences.toSet().toList();
  }

  Map<String, Map<String, dynamic>> _findSimilarUsersPatterns(
    String userId, 
    Map<String, Map<String, dynamic>> userBehaviorData
  ) {
    final similarPatterns = <String, Map<String, dynamic>>{};
    final currentUser = userBehaviorData[userId] ?? {};
    
    userBehaviorData.forEach((otherUserId, otherUserData) {
      if (otherUserId != userId) {
        final commonCategories = _findCommonCategories(currentUser, otherUserData);
        if (commonCategories.isNotEmpty) {
          similarPatterns[otherUserId] = otherUserData;
        }
      }
    });
    
    return similarPatterns;
  }

  List<String> _findCommonCategories(Map<String, dynamic> user1, Map<String, dynamic> user2) {
    final categories1 = (user1['preferredCategories'] as List? ?? []).cast<String>();
    final categories2 = (user2['preferredCategories'] as List? ?? []).cast<String>();
    return categories1.toSet().intersection(categories2.toSet()).toList();
  }

  List<String> _analyzeCategoryPatterns(
    Map<String, Map<String, dynamic>> similarUsers, 
    String mood
  ) {
    final categoryCounts = <String, int>{};
    
    for (final userData in similarUsers.values) {
      final preferences = (userData['moodPreferences'] as Map? ?? {})[mood] as List? ?? [];
      for (final category in preferences.cast<String>()) {
        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
      }
    }
    
    return categoryCounts.entries
        .sorted((a, b) => b.value.compareTo(a.value))
        .map((e) => e.key)
        .toList();
  }

  Map<String, String> _analyzeEffectiveTemplates(
    Map<String, Map<String, dynamic>> similarUsers, 
    String mood
  ) {
    return {
      'Music': 'Calming {genre} for {theme}',
      'Exercise': '{duration}-minute {activity} for {practice}',
      'Article': 'Managing {mood} through {approach}',
      'Affirmation': 'You are {quality} and deserve {value}'
    };
  }

  String _getRandomTemplate(String mood, String category) {
    final templates = _moodContentTemplates[mood]?[category] ?? ['$category for $mood'];
    final random = Random();
    return templates[random.nextInt(templates.length)];
  }

  String _mapPrincipleToCategory(String principle) {
    final mapping = {
      'Grounding Techniques': 'Exercise',
      'Breathing Exercises': 'Exercise', 
      'Progressive Relaxation': 'Exercise',
      'Behavioral Activation': 'Article',
      'Positive Psychology': 'Affirmation',
      'Social Connection': 'Article',
      'Preventive Care': 'Article',
      'Skill Building': 'Article',
      'Habit Formation': 'Article'
    };
    return mapping[principle] ?? 'Article';
  }

  String _createPrincipleBasedTemplate(String principle, String mood) {
    return '${principle} for ${mood.toLowerCase()} mood';
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}