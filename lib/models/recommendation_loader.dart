// recommendation_loader.dart
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';

class Recommendation {
  final String resourceId;
  final String title;
  final String category;
  final String mood;
  final String tags;
  final String description;
  final String link;
  final double popularity;
  final double rating;

  Recommendation({
    required this.resourceId,
    required this.title,
    required this.category,
    required this.mood,
    required this.tags,
    required this.description,
    required this.link,
    required this.popularity,
    required this.rating,
  });

  // Add this method to convert to AI-compatible format
  Map<String, dynamic> toAIMap() {
    return {
      'id': resourceId,
      'title': title,
      'category': category,
      'mood': mood,
      'description': description,
      'contentUrl': link,
      'type': category.toLowerCase(),
      'features': _calculateFeatures(),
      'popularity': popularity,
      'tags': tags.split(',').map((tag) => tag.trim()).toList(),
    };
  }

  Map<String, double> _calculateFeatures() {
    // Convert your CSV data to AI features
    // You can customize this based on your data
    return {
      'calming': rating / 5.0,
      'energizing': _calculateEnergizingScore(),
      'focus': popularity,
      'duration': 0.5, // Default, can be enhanced later
    };
  }

  double _calculateEnergizingScore() {
    // Custom logic based on mood and category
    if (mood.toLowerCase() == 'sad') return 0.7;
    if (mood.toLowerCase() == 'stressed') return 0.4;
    return 0.5;
  }
}

// Improved CSV loader with better error handling
Future<List<Recommendation>> loadRecommendationsFromCsv(String assetPath) async {
  try {
    print('📥 Loading CSV from: $assetPath');
    
    // Load the CSV file
    final csvString = await rootBundle.loadString(assetPath);
    print('✅ CSV loaded, length: ${csvString.length} characters');
    
    // Parse CSV
    final csvTable = const CsvToListConverter().convert(csvString, eol: '\n');
    print('📊 CSV parsed, ${csvTable.length} rows found');
    
    if (csvTable.isEmpty || csvTable.length < 2) {
      print('❌ CSV is empty or has no data rows');
      return [];
    }
    
    // Extract headers
    final headers = csvTable.first.map((header) => header.toString().trim()).toList();
    print('📋 Headers: $headers');
    
    // Process data rows
    final recommendations = <Recommendation>[];
    
    for (int i = 1; i < csvTable.length; i++) {
      final row = csvTable[i];
      
      // Skip empty rows
      if (row.isEmpty || row.every((cell) => cell.toString().trim().isEmpty)) {
        continue;
      }
      
      // Create a map from headers to values
      final rowMap = <String, String>{};
      for (int j = 0; j < headers.length; j++) {
        if (j < row.length) {
          rowMap[headers[j]] = row[j]?.toString().trim() ?? '';
        } else {
          rowMap[headers[j]] = '';
        }
      }
      
      // Parse numeric values with error handling
      double parseDouble(String value, [double defaultValue = 0.0]) {
        try {
          return double.tryParse(value) ?? defaultValue;
        } catch (e) {
          return defaultValue;
        }
      }
      
      // Create Recommendation object
      final recommendation = Recommendation(
        resourceId: rowMap['resource_id'] ?? 'id_$i',
        title: rowMap['title'] ?? 'Untitled',
        category: rowMap['category'] ?? 'Other',
        mood: rowMap['mood'] ?? 'Neutral',
        tags: rowMap['tags'] ?? '',
        description: rowMap['description'] ?? '',
        link: rowMap['link'] ?? '',
        popularity: parseDouble(rowMap['popularity'] ?? '0.5'),
        rating: parseDouble(rowMap['rating'] ?? '4.0'),
      );
      
      recommendations.add(recommendation);
    }
    
    print('🎉 Successfully loaded ${recommendations.length} recommendations');
    return recommendations;
    
  } catch (e, stackTrace) {
    print('❌ Error loading CSV: $e');
    print('Stack trace: $stackTrace');
    return [];
  }
}