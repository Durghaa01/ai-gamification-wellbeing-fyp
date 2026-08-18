import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:collection/collection.dart';
import 'package:flutter_application_mhproj/ui/elements/responsive_page_scaffold.dart';
import 'package:flutter_application_mhproj/design_system/tokens/typography.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// App design system
import '../../../design_system/tokens/color_tokens.dart';
import '../../../models/recommendation_loader.dart';
import '../domain/generative_ai_engine.dart';

// ============================================
// API SERVICE FOR PYTHON BACKEND
// ============================================

class RecommendationRequest {
  final String userId;
  final String mood;
  final Map<String, dynamic> context;

  RecommendationRequest({
    required this.userId,
    required this.mood,
    required this.context,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'mood': mood,
      'context': context,
    };
  }
}

class AIService {
  // For testing: Use localhost for emulator, your computer's IP for real device
  static const String baseUrl = 'https://demo-fyp-ai.mockapi.io'; // Android emulator
  // static const String baseUrl = 'http://192.168.x.x:5000'; // Your computer IP for real device
  
  static Future<Map<String, dynamic>> getRecommendations({
    required String userId,
    required String mood,
    required Map<String, dynamic> context,
  }) async {
    // For demonstration, return mock data
  await Future.delayed(Duration(seconds: 1)); // Simulate API delay
  
  return {
    'success': true,
    'mood': mood,
    'recommendations': [
      {
        'id': 'demo_cb_1',
        'title': 'Calming Piano for $mood',
        'description': 'Content-based: Matched your mood using TF-IDF',
        'category': 'Music',
        'mood': mood,
        'url': 'https://youtube.com/watch?v=test',
        'ai_confidence': 0.92,
        'technique_used': 'content_based',
        'explanation': 'Content similarity: 92% match with your preferences',
      },
      {
        'id': 'demo_cf_1',
        'title': 'Breathing Exercises for $mood',
        'description': 'Collaborative: Users like you found this helpful',
        'category': 'Exercise',
        'mood': mood,
        'url': 'https://youtube.com/watch?v=test2',
        'ai_confidence': 0.87,
        'technique_used': 'collaborative',
        'explanation': '85% of similar users engaged with this content',
      },
      {
        'id': 'demo_cb_1',
        'title': 'Mindful Meditation for $mood',
        'description': 'Contextual Bandit: Optimized for your current context',
        'category': 'Meditation',
        'mood': mood,
        'url': 'https://youtube.com/watch?v=test3',
        'ai_confidence': 0.95,
        'technique_used': 'contextual_bandit',
        'explanation': 'Adaptive learning selected this based on time & mood',
      },
    ],
  };
}
  
  static Future<bool> recordInteraction({
    required String userId,
    required String resourceId,
    required String interactionType,
    required String mood,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/interaction');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'resource_id': resourceId,
          'interaction_type': interactionType,
          'mood': mood,
        }),
        ).timeout(Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      print('⚠️ Failed to record interaction: $e');
      return false;
    }
  }
  
  static Future<bool> checkApiHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/health'),
      ).timeout(Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('❌ API not available: $e');
      return false;
    }
  }
  
  // Fallback simulated recommendations (your current AI)
  static Map<String, dynamic> _getSimulatedRecommendations(String mood) {
    final simulatedData = {
      'success': true,
      'mood': mood,
      'recommendations': [
        {
          'id': 'sim_1',
          'title': 'Calming Music for $mood',
          'description': 'AI-generated content for your current mood',
          'category': 'Music',
          'mood': mood,
          'url': 'https://youtube.com/search?q=$mood+music',
          'ai_confidence': 0.85,
          'technique_used': 'content_based',
          'explanation': 'Matched with your mood and preferences',
        },
        {
          'id': 'sim_2',
          'title': 'Breathing Exercise for $mood',
          'description': 'Quick exercise to help with your current state',
          'category': 'Exercise',
          'mood': mood,
          'url': 'https://youtube.com/search?q=$mood+exercise',
          'ai_confidence': 0.78,
          'technique_used': 'collaborative',
          'explanation': 'Similar users found this helpful',
        },
        {
          'id': 'sim_3',
          'title': 'Guided Meditation for $mood',
          'description': 'Meditation session tailored to your needs',
          'category': 'Meditation',
          'mood': mood,
          'url': 'https://youtube.com/search?q=$mood+meditation',
          'ai_confidence': 0.92,
          'technique_used': 'contextual_bandit',
          'explanation': 'Adapted based on context and learning',
        },
      ],
    };
    
    return simulatedData;
  }
}
 enum DemoMode { integrated, component }
class MyResourcePage extends StatefulWidget {
  const MyResourcePage({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  @override
  State<MyResourcePage> createState() => _MyResourcePageState();
}

class _MyResourcePageState extends State<MyResourcePage> {
  String selectedMood = 'Neutral';
  final Set<String> likedResources = {};
  bool _isLoading = true;
  bool _showAIRecommendations = false;
  List<DynamicContent> _dynamicAIRecommendations = [];
  final GenerativeAIEngine generativeAI = GenerativeAIEngine();
  Map<String, dynamic> _userProfile = {};
  Map<String, dynamic> _userContext = {};
  List<Recommendation> _resourcesFromCsv = [];
  String _csvLoadingError = '';
  late bool _isDarkMode; 

  // ======== ADD THESE 3 LINES RIGHT HERE ========
  DemoMode _demoMode = DemoMode.component;
  bool _simulatingTeamData = false;
  // ==============================================

  // ADD THESE NEW VARIABLES:
  String _apiStatus = 'Checking AI connection...';
  bool _apiConnected = false;
  List<String> _aiTechniquesUsed = [];

  @override
  void initState() {
    super.initState();
    _initializeUserProfile();
    _initializeUserContext();
    _initializeApp();
    _isDarkMode = widget.isDarkMode;
  }

  Future<void> _initializeUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final uniqueUserId = prefs.getString('uniqueUserId') ?? _generateUniqueUserId();
    
    setState(() {
      _userProfile = {
        'userId': uniqueUserId,
        'preferredCategories': prefs.getStringList('preferredCategories') ?? ['Music', 'Exercise'],
        'interactionHistory': prefs.getStringList('interactionHistory') ?? [],
        'personalityTraits': _analyzePersonalityTraits(),
      };
    });
  }

  String _generateUniqueUserId() {
    final now = DateTime.now();
    final uniqueId = 'user_${now.millisecondsSinceEpoch}_${now.microsecondsSinceEpoch}';
    
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('uniqueUserId', uniqueId);
    });
    
    return uniqueId;
  }

  Future<void> _initializeUserContext() async {
    final prefs = await SharedPreferences.getInstance();
    final currentTime = DateTime.now();
    final hour = currentTime.hour;
    
    setState(() {
      _userContext = {
        'timeOfDay': hour < 12 ? 'morning' : hour < 18 ? 'afternoon' : 'evening',
        'stressLevel': prefs.getInt('currentStressLevel') ?? 5,
        'lastMoodUpdate': prefs.getString('lastMood') ?? 'Neutral',
      };
    });
  }

  Future<void> _initializeApp() async {
    await _loadLikedResources();
    await _loadResourcesCsv();
    await _initializeUserProfile();
    await _initializeUserContext();
    
    // Check API connection
    await _checkApiConnection();
    
    setState(() {
      _isLoading = false;
    });
  }

    Future<void> _checkApiConnection() async {
    setState(() {
      _apiStatus = 'Connecting to AI server...';
    });
    
    final isConnected = await AIService.checkApiHealth();
    
    setState(() {
      _apiConnected = isConnected;
      _apiStatus = isConnected ? '✅ Connected to AI Server' : '⚠️ Using simulated AI';
      _showAIRecommendations = true;
    });
    
    if (isConnected) {
      await _generateAIRecommendations();
    } else {
      // Use your existing AI if API not available
      _generateDynamicAIRecommendations();
    }
  }

    Future<void> _generateAIRecommendations() async {
    print('🧠 Calling Python AI API for mood: $selectedMood');
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final response = await AIService.getRecommendations(
        userId: _userProfile['userId'],
        mood: selectedMood,
        context: _userContext,
      );
      
      if (response['success'] == true) {
        final recommendations = List<Map<String, dynamic>>.from(response['recommendations']);
        
        // Track techniques used
        final techniques = recommendations.map((r) => r['technique_used'].toString()).toSet().toList();
        
        // Convert to DynamicContent
        final dynamicContents = recommendations.map((rec) {
          return DynamicContent(
            id: rec['id'],
            title: rec['title'],
            description: rec['description'],
            contentUrl: rec['url'],
            type: rec['category'].toLowerCase(),
            aiConfidence: (rec['ai_confidence'] as num).toDouble(),
            category: rec['category'],
            mood: rec['mood'],
            techniqueUsed: rec['technique_used'],
            explanation: rec['explanation'],
          );
        }).toList();
        
        setState(() {
          _dynamicAIRecommendations = dynamicContents;
          _aiTechniquesUsed = techniques;
          _isLoading = false;
        });
        
        print('✅ Received ${_dynamicAIRecommendations.length} AI recommendations');
        print('🤖 Techniques used: $_aiTechniquesUsed');
      }
    } catch (e) {
      print('❌ Error getting AI recommendations: $e');
      // Fallback to your existing AI
      _generateDynamicAIRecommendations();
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLikedResources() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLikes = prefs.getStringList('likedResources') ?? [];
    setState(() {
      likedResources.addAll(savedLikes);
    });
  }

  Future<void> _saveLikedResources() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('likedResources', likedResources.toList());
  }

  Future<void> _loadResourcesCsv() async {
    try {
      print('🔄 Starting CSV load...');
      setState(() {
        _isLoading = true;
        _csvLoadingError = '';
      });

      final resources = await loadRecommendationsFromCsv('assets/data/resources.csv');
      
      if (resources.isEmpty) {
        setState(() {
          _csvLoadingError = 'No data found in CSV file';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _resourcesFromCsv = resources;
        _isLoading = false;
      });
      
      print('✅ CSV loading completed: ${_resourcesFromCsv.length} items');
      
    } catch (e) {
      print('❌ CSV loading failed: $e');
      setState(() {
        _csvLoadingError = 'Failed to load CSV: $e';
        _isLoading = false;
      });
    }
  }

  void _generateDynamicAIRecommendations() {
    print('🎨 Starting generative AI recommendations for mood: $selectedMood');

    setState(() {
      _dynamicAIRecommendations = generativeAI.generateUniqueRecommendations(
        currentMood: selectedMood,
        userId: _userProfile['userId'],
        userLikedTitles: likedResources.toList(),
        userContext: _userContext,
        userProfile: _userProfile,
        userBehaviorData: _getUserBehaviorData(),
        totalLimit: 8,
      );
    });
    
     // ADD THIS LINE:
    setState(() {
      _aiTechniquesUsed = ['content_based', 'collaborative', 'contextual_bandit'];
    });

    print('🎨 GENERATED ${_dynamicAIRecommendations.length} UNIQUE recommendations for user ${_userProfile['userId']}');
  }

  Map<String, Map<String, dynamic>> _getUserBehaviorData() {
    return {
      _userProfile['userId']: _userProfile,
      'user_001': {
        'preferredCategories': ['Music', 'Affirmation'],
        'moodPreferences': {
          'Stressed': ['Music', 'Exercise'],
          'Sad': ['Music', 'Affirmation'],
          'Neutral': ['Article', 'Exercise']
        }
      },
      'user_002': {
        'preferredCategories': ['Exercise', 'Article'],
        'moodPreferences': {
          'Stressed': ['Exercise', 'Article'],
          'Sad': ['Music', 'Exercise'],
          'Neutral': ['Music', 'Affirmation']
        }
      }
    };
  }

  Map<String, dynamic> _analyzePersonalityTraits() {
    final traits = <String, dynamic>{};
    final likedTitles = likedResources.toList();
    
    traits['prefersActiveContent'] = likedTitles.any((title) => 
        title.toLowerCase().contains('exercise') || 
        title.toLowerCase().contains('dance') ||
        title.toLowerCase().contains('workout'));
    
    traits['prefersCalmContent'] = likedTitles.any((title) =>
        title.toLowerCase().contains('calm') ||
        title.toLowerCase().contains('relax') ||
        title.toLowerCase().contains('peaceful') ||
        title.toLowerCase().contains('meditation'));
    
    traits['prefersMusic'] = likedTitles.any((title) =>
        title.toLowerCase().contains('music') ||
        title.toLowerCase().contains('song') ||
        title.toLowerCase().contains('playlist'));
    
    if (likedTitles.length > 8) {
      traits['engagementLevel'] = 'high';
    } else if (likedTitles.length > 3) {
      traits['engagementLevel'] = 'medium';
    } else {
      traits['engagementLevel'] = 'low';
    }
    
    final moodCounts = <String, int>{};
    for (final resource in _resourcesFromCsv) {
      if (likedTitles.contains(resource.title)) {
        moodCounts[resource.mood] = (moodCounts[resource.mood] ?? 0) + 1;
      }
    }
    
    traits['preferredMoods'] = moodCounts.entries
        .sorted((a, b) => b.value.compareTo(a.value))
        .map((e) => e.key)
        .toList();
    
    return traits;
  }

  void _openDynamicContent(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot open: $url')),
      );
    }
  }

  void _showLikedResourcesDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.favorite_rounded, color: Colors.red),
          SizedBox(width: 8),
          Text('All Saved Resources (${likedResources.length})'),
        ],
      ),
      content: Container(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: likedResources.length,
          itemBuilder: (context, index) {
            final savedIdentifier = likedResources.elementAt(index);
            
            // First, try to find in dynamic AI recommendations
            DynamicContent? dynamicContent;
            String displayTitle = savedIdentifier;
            String displayDescription = 'Saved resource';
            
            // Look for matching content
            for (var content in _dynamicAIRecommendations) {
              final contentIdentifier = content.id ?? content.title;
              if (contentIdentifier == savedIdentifier) {
                dynamicContent = content;
                displayTitle = content.title;
                displayDescription = content.description;
                break;
              }
            }
            
            // If not found in dynamic, check CSV resources
            if (dynamicContent == null) {
              for (var resource in _resourcesFromCsv) {
                final resourceIdentifier = resource.title;
                if (resourceIdentifier == savedIdentifier) {
                  displayTitle = resource.title;
                  displayDescription = resource.description;
                  break;
                }
              }
            }
            
            return Card(
              margin: EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: Icon(Icons.favorite, color: Colors.red, size: 20),
                title: Text(displayTitle),
                subtitle: Text(
                  displayDescription,
                  style: TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: Icon(Icons.remove_circle_outline, color: Colors.grey),
                  onPressed: () {
                    setState(() {
                      likedResources.remove(savedIdentifier);
                      _saveLikedResources();
                    });
                    Navigator.pop(context);
                    if (likedResources.isNotEmpty) {
                      _showLikedResourcesDialog(context);
                    }
                  },
                ),
                onTap: () {
                  Navigator.pop(context);
                  if (dynamicContent != null && dynamicContent!.contentUrl.isNotEmpty) {
                    _openDynamicContent(dynamicContent!.contentUrl);
                  } else {
                    // Try to open from CSV or search
                    final csvResource = _resourcesFromCsv.firstWhere(
                      (rec) => rec.title == savedIdentifier,
                      orElse: () => Recommendation(
                        resourceId: '',
                        title: '',
                        category: '',
                        mood: '',
                        tags: '',
                        description: '',
                        link: '',
                        popularity: 0.0,
                        rating: 0.0,
                      ),
                    );
                    
                    if (csvResource.link.isNotEmpty) {
                      _openDynamicContent(csvResource.link);
                    } else {
                      final searchUrl = 'https://www.google.com/search?q=${Uri.encodeComponent(displayTitle)}';
                      _openDynamicContent(searchUrl);
                    }
                  }
                },
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close'),
        ),
      ],
    ),
  );
}
  // THEME-INTEGRATED UI WIDGETS

@override
Widget build(BuildContext context) {
  return MindWellResponsiveScaffold(
    appBar: AppBar(
      title: const Text('My Resources'),
      centerTitle: true,
      actions: [
        Switch(
          value: _isDarkMode,
          onChanged: (value) {
            setState(() => _isDarkMode = value);
            widget.onThemeChanged(value);
          },
        ),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Text(_isDarkMode ? '☾' : '☀'),
        ),
      ],
    ),
    scrollable: true,
    padding: const EdgeInsets.all(0),
    child: _isLoading 
      ? _buildLoadingState(context) 
      : _buildMainContent(context),
  );
}

Widget _buildMainContent(BuildContext context) {
  return Container(
    color: Theme.of(context).colorScheme.background,
    child: SingleChildScrollView(
      child: Column(
        children: [
          _buildDemoModeSelector(),
          _demoMode == DemoMode.integrated
              ? _buildIntegratedDemo(context)
              : _buildComponentDemo(context),
        ],
      ),
    ),
  );
}

// ========== ADD THIS METHOD ==========
Widget _buildDemoModeSelector() {
  return Container(
    padding: EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.1),
      border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.settings, size: 16, color: Theme.of(context).colorScheme.outline),
        SizedBox(width: 8),
        Text(
          'Demo Mode:',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        SizedBox(width: 12),
        ChoiceChip(
          label: Text('Integrated System'),
          selected: _demoMode == DemoMode.integrated,
          onSelected: (selected) {
            if (selected) {
              setState(() {
                _demoMode = DemoMode.integrated;
                _startIntegratedDemo();
              });
            }
          },
        ),
        SizedBox(width: 8),
        ChoiceChip(
          label: Text('Component Testing'),
          selected: _demoMode == DemoMode.component,
          onSelected: (selected) {
            if (selected) {
              setState(() {
                _demoMode = DemoMode.component;
              });
            }
          },
        ),
      ],
    ),
  );
}
// =====================================

// ========== ADD THIS METHOD ==========
Widget _buildIntegratedDemo(BuildContext context) {
  return SingleChildScrollView(
    padding: EdgeInsets.all(20),
    child: Column(
      children: [
        // Header
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[50]!, Colors.purple[50]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            children: [
              Icon(Icons.auto_awesome, size: 40, color: Colors.purple),
              SizedBox(height: 12),
              Text(
                'Integrated System Demo',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple[800],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Mood detected automatically from other features',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
          ),
        ),
        SizedBox(height: 20),
        
        // Team Data Simulation
        _buildTeamDataSimulation(),
        SizedBox(height: 20),
        
        // Recommendations Section
        if (_simulatingTeamData)
          _buildAutoRecommendations()
        else
          _buildWaitingForData(),
      ],
    ),
  );
}
// =====================================

void _startIntegratedDemo() {
  setState(() {
    _simulatingTeamData = false;
  });
}

// ========== ADD THIS METHOD ==========
Widget _buildTeamDataSimulation() {
  return Card(
    elevation: 3,
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people, color: Colors.green),
              SizedBox(width: 8),
              Text(
                'Team Data Simulation',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          SizedBox(height: 12),
          
          // Simulated data rows
          _buildDataRow('📝 Journal Analysis', 'Detected: Stressed (85% confidence)'),
          _buildDataRow('📊 Mood Tracker', 'Current: Anxious (score: 7/10)'),
          _buildDataRow('⏰ Quick Check-in', 'Recent: Overwhelmed'),
          _buildDataRow('🧠 AI Analysis', 'Consolidated mood: Stressed'),
          
          SizedBox(height: 16),
          
          if (!_simulatingTeamData)
            ElevatedButton.icon(
              icon: Icon(Icons.play_arrow),
              label: Text('Simulate Data Flow'),
              onPressed: () {
                setState(() {
                  _simulatingTeamData = true;
                });
                // Auto-generate recommendations
                Future.delayed(Duration(seconds: 1), () {
                  _generateAutoRecommendations();
                });
              },
            )
          else
            Text(
              '✅ Data received and processed automatically',
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
            ),
        ],
      ),
    ),
  );
}
// =====================================

// ========== ADD THIS METHOD ==========
Widget _buildDataRow(String label, String value) {
  return Padding(
    padding: EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Text(value, style: TextStyle(color: Colors.grey[700])),
        ),
      ],
    ),
  );
}
// =====================================

// ========== ADD THIS METHOD ==========
Widget _buildWaitingForData() {
  return Container(
    padding: EdgeInsets.all(30),
    decoration: BoxDecoration(
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: Column(
      children: [
        Icon(Icons.hourglass_empty, size: 50, color: Colors.grey[400]),
        SizedBox(height: 16),
        Text(
          'Waiting for team data...',
          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
        ),
        SizedBox(height: 8),
        Text(
          'Click "Simulate Data Flow" above to see integrated system in action',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[500]),
        ),
      ],
    ),
  );
}
// =====================================

// ========== ADD THIS METHOD ==========
void _generateAutoRecommendations() {
  // Simulate auto-detected mood from team features
  final autoMood = 'Stressed';
  
  setState(() {
    _dynamicAIRecommendations = [
      DynamicContent(
        id: 'auto_1',
        title: 'Auto: Calming Piano Meditation',
        description: 'Automatically recommended based on detected stress',
        contentUrl: 'https://youtube.com',
        type: 'music',
        aiConfidence: 0.94,
        category: 'Music',
        mood: autoMood,
        techniqueUsed: 'content_based',
        explanation: 'Auto-detected: High stress → Calming music',
      ),
      DynamicContent(
        id: 'auto_2',
        title: 'Auto: 5-Minute Breathing',
        description: 'Quick relief for detected anxiety',
        contentUrl: 'https://youtube.com',
        type: 'exercise',
        aiConfidence: 0.88,
        category: 'Exercise',
        mood: autoMood,
        techniqueUsed: 'collaborative',
        explanation: 'Users with similar stress patterns found this helpful',
      ),
      DynamicContent(
        id: 'auto_3',
        title: 'Auto: Stress Management Guide',
        description: 'Personalized for your current stress level',
        contentUrl: 'https://psychologytoday.com',
        type: 'article',
        aiConfidence: 0.91,
        category: 'Article',
        mood: autoMood,
        techniqueUsed: 'contextual_bandit',
        explanation: 'Adapted to time of day and stress pattern',
      ),
    ];
    
    _aiTechniquesUsed = ['content_based', 'collaborative', 'contextual_bandit'];
    _isLoading = false;
  });
}
// =====================================

// ========== ADD THIS METHOD ==========
Widget _buildAutoRecommendations() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.green),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Recommendations Generated',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Based on auto-detected mood from team features',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      SizedBox(height: 20),
      ..._dynamicAIRecommendations.map((content) => 
          _buildRecommendationCard(context,content)),
    ],
  );
}
// =====================================



  Widget _buildLoadingState(BuildContext context) {
        
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isDarkMode 
                      ? [MindWellColors.darkGray, MindWellColors.lightGreen]
                      : [Color(0xFFD7CCC8), Color(0xFFBCAAA4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 40),
              ),
              SizedBox(height: 20),
              Text(
                'Your AI is crafting personalized recommendations...',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Using advanced AI to understand your needs',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }

  Widget _buildMoodSelector(BuildContext context) {
        
        return Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isDarkMode 
                ? [MindWellColors.darkGray, MindWellColors.lightGreen.withOpacity(0.7)]
                : [Color(0xFFD7CCC8), Color(0xFFBCAAA4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (_isDarkMode ? MindWellColors.lightGreen : Color(0xFFA1887F)).withOpacity(0.3),
                blurRadius: 15,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.mood_rounded, color: Colors.white, size: 24),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'How are you feeling today?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                   _buildMoodChip(context, '😊 Neutral', 'Neutral'), // ✅ PASS CONTEXT
                   _buildMoodChip(context, '😔 Sad', 'Sad'),
                   _buildMoodChip(context, '😰 Stressed', 'Stressed'),
                   _buildMoodChip(context, '🌟 All Moods', 'All'),
                ],
              ),
            ],
          ),
        );
      }

  Widget _buildMoodChip(BuildContext context, String label, String mood) {
    final isSelected = selectedMood == mood;
    
        return GestureDetector(
                    onTap: () {
            setState(() {
              selectedMood = mood;
              if (_showAIRecommendations) {
                // CHANGE THIS LINE:
                if (_apiConnected) {
                  _generateAIRecommendations();
                } else {
                  _generateDynamicAIRecommendations();
                }
              }
            });
          },
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected 
                ? Colors.white 
                : Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isSelected 
                  ? (Theme.of(context).brightness == Brightness.dark 
                      ? MindWellColors.darkGray 
                      : Color(0xFF8D6E63))
                  : Colors.white,
              ),
            ),
          ),
        );
      }
  

  Widget _buildUserMessageCard(BuildContext context) {
        return Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 20,
                offset: Offset(0, 5),
              ),
            ],
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.psychology_alt_rounded, color: Color(0xFF10B981), size: 24),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedMood == 'All'
                      ? "Hello! I'm your AI wellness assistant 🌟"
                      : "I understand you're feeling $selectedMood today",
                      style: TextStyle( 
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                    SizedBox(height: 8),
                    Text(
                      selectedMood == 'All'
                          ? "Here are personalized resources curated for your overall well-being and growth journey."
                          : "I've created these resources specifically to support you right now. Each recommendation is tailored to help you feel better.",
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.outline,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

  Widget _buildLikedResourcesSection(BuildContext context) {
        return Column(
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFEF7FF), Color(0xFFF0F9FF).withOpacity(0.5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.favorite_rounded, color: Theme.of(context).colorScheme.primary, size: 24),
                      ),
                      SizedBox(width: 12),
                      Text(   
                    'Your Saved Resources',
                    style: TextStyle(
                     fontSize: 16, // ✅ CHANGE THIS
                     color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Resources you\'ve loved and saved for later',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: likedResources.map((title) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: Color(0xFFFECACA),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite_rounded, color: Color(0xFFEF4444), size: 16),
                      SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 150),
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            
            if (likedResources.isNotEmpty) ...[
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      child: TextButton.icon(
                        icon: Icon(Icons.play_arrow_rounded, size: 20),
                        label: Text(
                          'Explore All',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        onPressed: () {
                          _showLikedResourcesDialog(context);
                        },
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF34D399)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextButton.icon(
                        icon: Icon(Icons.shuffle_rounded, color: Colors.white, size: 20),
                        label: Text(
                          'Shuffle',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        onPressed: () {
                          if (likedResources.isNotEmpty) {
                            final randomResource = likedResources.elementAt(
                                DateTime.now().millisecondsSinceEpoch % likedResources.length);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Try: $randomResource'),
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      }

  Widget _buildAIRecommendationsSection(BuildContext context) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                ),
                SizedBox(width: 12),
                Text(
                  'AI-Powered Recommendations',
                  style: MindWellTypography.sectionSubtitle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Personalized content generated in real-time using advanced AI',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            SizedBox(height: 20),
            
            ..._dynamicAIRecommendations.map((content) => _buildRecommendationCard(context, content)),
          ],
        );
      }
  

  Widget _buildRecommendationCard(BuildContext context, DynamicContent content) {
        
        
        final confidenceColor = content.aiConfidence > 0.8 
      ? Color(0xFF10B981) 
      : content.aiConfidence > 0.6 
          ? Color(0xFFF59E0B) 
          : Color(0xFFEF4444);
          
        return Container(
          margin: EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 15,
                offset: Offset(0, 5),
              ),
            ],
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getCategoryColor(content.category).withOpacity(0.05),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(content.category),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getCategoryIcon(content.category),
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      content.category,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _getCategoryColor(content.category),
                      ),
                    ),
                    Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: confidenceColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            color: confidenceColor,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${(content.aiConfidence * 100).toInt()}% match',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: confidenceColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      content.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                        height: 1.3,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      content.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: likedResources.contains(content.id ?? content.title)
                                ? Color(0xFFFEF2F2)
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: Icon(
                              likedResources.contains(content.title)
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: likedResources.contains(content.title)
                                  ? Color(0xFFEF4444)
                                  : Theme.of(context).colorScheme.outline,
                            ),
                            onPressed: () {
                              setState(() {
                                final resourceIdentifier = content.title; 
                                if (likedResources.contains(resourceIdentifier)) {
                                likedResources.remove(resourceIdentifier);
                                } else {
                                likedResources.add(resourceIdentifier);
                              }
                                _saveLikedResources();
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 8),
                        
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).colorScheme.primary,
                                  Theme.of(context).colorScheme.secondary,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextButton.icon(
                              icon: Icon(Icons.explore_rounded, color: Theme.of(context).colorScheme.onPrimary, size: 18),
                              label: Text(
                                'Explore',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onPressed: () => _openDynamicContent(content.contentUrl),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

  Widget _buildLegend(BuildContext context) {
        return Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.favorite_rounded, color: Color(0xFFEF4444), size: 16),
              ),
              SizedBox(width: 8),
              Text(
                'Tap heart to save your favorites',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }
    
  Widget _buildComponentDemo (BuildContext context) {
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          _buildMoodSelector(context),
          SizedBox(height: 20),
          SizedBox(height: 20),
          _buildUserMessageCard(context),
          SizedBox(height: 20),
          SizedBox(height: 20),
          if (likedResources.isNotEmpty) _buildLikedResourcesSection(context),
          if (_dynamicAIRecommendations.isNotEmpty) ...[
            if (likedResources.isNotEmpty) SizedBox(height: 24),
            _buildAIRecommendationsSection(context),
          ],
          SizedBox(height: 24),
          _buildLegend(context),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Music':
        return Icons.music_note;
      case 'Exercise':
        return Icons.self_improvement;
      case 'Affirmation':
        return Icons.favorite;
      case 'Article':
        return Icons.article;
      case 'Counselling':
        return Icons.chat_bubble;
      default:
        return Icons.help;
    }
  }

  
    Color _getTechniqueColor(String technique) {
    switch (technique) {
      case 'content_based': return Colors.green;
      case 'collaborative': return Colors.blue;
      case 'contextual_bandit': return Colors.purple;
      default: return Colors.grey;
    }
  }

  Color _getCategoryColor(String category) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    switch (category) {
      case 'Music':
        return isDarkMode ? MindWellColors.lightGreen : Color(0xFF8B5CF6);
      case 'Exercise':
        return isDarkMode ? Colors.cyan : Color(0xFF10B981);
      case 'Article':
        return isDarkMode ? Colors.amber : Color(0xFFF59E0B);
      case 'Affirmation':
        return isDarkMode ? Colors.pink : Color(0xFFEC4899);
      case 'Counselling':
        return isDarkMode ? Colors.red : Color(0xFFEF4444);
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }
}