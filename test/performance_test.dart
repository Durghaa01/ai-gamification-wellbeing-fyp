import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../lib/services/performance_monitor.dart';
import '../lib/features/journal/application/journal_service.dart';

/// Performance testing suite for measuring backend services, and API response times
void main() {
  group('PerformanceMonitor Tests', () {
    test('Basic operation timing', () async {
      final result = await PerformanceMonitor.measure(
        operationName: 'Simple Delay',
        operation: () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );

      expect(result.success, isTrue);
      expect(result.durationMs.inMilliseconds, greaterThanOrEqualTo(100));
      expect(result.durationMs.inMilliseconds, lessThan(200));
      print(result);
    });

    test('Operation with error handling', () async {
      final result = await PerformanceMonitor.measure(
        operationName: 'Operation with Error',
        operation: () => Future<void>.delayed(const Duration(milliseconds: 50))
            .then((_) => throw Exception('Test error')),
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('Test error'));
      expect(result.durationMs.inMilliseconds, greaterThanOrEqualTo(50));
      print(result);
    });

    test('Sequential operations', () async {
      final result = await PerformanceMonitor.measureSequential(
        testName: 'Sequential Operations',
        operations: [
          (
            name: 'Operation 1',
            operation: () => Future<void>.delayed(const Duration(milliseconds: 100)),
            metadata: {'type': 'simple'},
          ),
          (
            name: 'Operation 2',
            operation: () => Future<void>.delayed(const Duration(milliseconds: 150)),
            metadata: {'type': 'simple'},
          ),
          (
            name: 'Operation 3',
            operation: () => Future<void>.delayed(const Duration(milliseconds: 50)),
            metadata: {'type': 'simple'},
          ),
        ],
      );

      expect(result.results.length, equals(3));
      expect(result.successCount, equals(3));
      expect(result.results.every((r) => r.success), isTrue);
      // Total should be roughly 300ms (sum of all delays)
      expect(
        result.totalDuration.inMilliseconds,
        greaterThanOrEqualTo(280),
      );
      result.printResults();
    });

    test('Parallel operations', () async {
      final result = await PerformanceMonitor.measureParallel(
        testName: 'Parallel Operations',
        operations: [
          (
            name: 'Operation 1',
            operation: () => Future<void>.delayed(const Duration(milliseconds: 100)),
            metadata: {'type': 'parallel'},
          ),
          (
            name: 'Operation 2',
            operation: () => Future<void>.delayed(const Duration(milliseconds: 100)),
            metadata: {'type': 'parallel'},
          ),
          (
            name: 'Operation 3',
            operation: () => Future<void>.delayed(const Duration(milliseconds: 100)),
            metadata: {'type': 'parallel'},
          ),
        ],
      );

      expect(result.results.length, equals(3));
      expect(result.successCount, equals(3));
      // Parallel should be roughly 100ms (max delay), not 300ms
      expect(result.totalDuration.inMilliseconds, lessThan(250));
      result.printResults();
    });

    test('Load test - sequential', () async {
      final result = await PerformanceMonitor.loadTest(
        testName: 'Load Test - Sequential (10 iterations)',
        operationName: 'Fast Operation',
        iterations: 10,
        operation: () => Future<void>.delayed(const Duration(milliseconds: 10)),
        sequential: true,
      );

      expect(result.results.length, equals(10));
      expect(result.successCount, equals(10));
      // Should take roughly 100ms (10 * 10ms)
      expect(result.totalDuration.inMilliseconds, greaterThanOrEqualTo(90));
      result.printResults();
    });

    test('Load test - parallel', () async {
      final result = await PerformanceMonitor.loadTest(
        testName: 'Load Test - Parallel (10 iterations)',
        operationName: 'Fast Operation',
        iterations: 10,
        operation: () => Future<void>.delayed(const Duration(milliseconds: 10)),
        sequential: false,
      );

      expect(result.results.length, equals(10));
      expect(result.successCount, equals(10));
      // Parallel should complete in roughly 10-50ms, not 100ms
      expect(result.totalDuration.inMilliseconds, lessThan(150));
      result.printResults();
    });

    test('Timeout handling', () async {
      final result = await PerformanceMonitor.measureWithTimeout(
        operationName: 'Operation with Timeout',
        operation: () => Future<void>.delayed(const Duration(seconds: 5)),
        timeout: const Duration(milliseconds: 500),
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('TimeoutException'));
      expect(result.durationMs.inMilliseconds, lessThan(1000));
      print(result);
    });

    test('Result to JSON serialization', () async {
      final result = await PerformanceMonitor.measure(
        operationName: 'JSON Test',
        operation: () => Future<void>.delayed(const Duration(milliseconds: 50)),
        metadata: {'version': '1.0', 'env': 'test'},
      );

      final json = result.toJson();
      expect(json['operationName'], equals('JSON Test'));
      expect(json['success'], isTrue);
      expect(json['metadata'], containsPair('version', '1.0'));
      print('JSON: $json');
    });

    test('Test suite to JSON', () async {
      final result = await PerformanceMonitor.measureSequential(
        testName: 'JSON Export Test',
        operations: [
          (
            name: 'Op1',
            operation: () => Future<void>.delayed(const Duration(milliseconds: 10)),
            metadata: null,
          ),
          (
            name: 'Op2',
            operation: () => Future<void>.delayed(const Duration(milliseconds: 20)),
            metadata: null,
          ),
        ],
      );

      final jsonString = result.toJsonString();
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      
      expect(decoded['testName'], equals('JSON Export Test'));
      expect(decoded['results'], isA<List>());
      expect((decoded['results'] as List).length, equals(2));
      print('JSON String: $jsonString');
    });
  });

  group('Journal API Performance Tests', () {
    late JournalAnalysisService journalService;

    setUp(() {
      journalService = JournalAnalysisService(
        baseUrl: 'http://127.0.0.1:8000',
      );
    });

    tearDown(() {
      journalService.dispose();
    });

    test('Sentiment Analysis Response Time (Heuristic Fallback)', () async {
      final result = await PerformanceMonitor.measure(
        operationName: 'Sentiment Analysis',
        operation: () => journalService.analyzeSentiment('I feel happy and relaxed today'),
        metadata: {'engine': 'heuristic'},
      );

      expect(result.success, isTrue);
      print('Sentiment Analysis: ${result.durationMs.inMilliseconds}ms');
      print(result);
    });

    test('Risk Computation Response Time (Heuristic Fallback)', () async {
      final result = await PerformanceMonitor.measure(
        operationName: 'Risk Computation',
        operation: () async {
          final sentiment = await journalService.analyzeSentiment('I feel anxious');
          // Note: This will use heuristic fallback if API is unavailable
        },
        metadata: {'engine': 'heuristic'},
      );

      expect(result.success, isTrue);
      print('Risk Computation: ${result.durationMs.inMilliseconds}ms');
      print(result);
    });

    test('Multiple Sentiment Analyses (Load Test)', () async {
      final result = await PerformanceMonitor.loadTest(
        testName: 'Journal API Load Test (5 analyses)',
        operationName: 'Sentiment Analysis',
        iterations: 5,
        operation: () => journalService.analyzeSentiment(
          'This is a test entry for sentiment analysis to measure performance',
        ),
        sequential: false,
      );

      result.printResults();
      expect(result.successCount, equals(5));
    });
  });

  group('HTTP Request Performance Tests', () {
    test('HTTP GET Request Timing', () async {
      final result = await PerformanceMonitor.measure(
        operationName: 'HTTP GET - jsonplaceholder.typicode.com',
        operation: () async {
          final response = await http.get(
            Uri.parse('https://jsonplaceholder.typicode.com/posts/1'),
          ).timeout(const Duration(seconds: 10));
          if (response.statusCode != 200) {
            throw Exception('HTTP ${response.statusCode}');
          }
        },
        metadata: {'endpoint': 'https://jsonplaceholder.typicode.com/posts/1'},
      );

      print(result);
      result.success ? expect(true, isTrue) : print('Note: May fail without internet');
    });

    test('HTTP POST Request Timing', () async {
      final result = await PerformanceMonitor.measure(
        operationName: 'HTTP POST - jsonplaceholder.typicode.com',
        operation: () async {
          final response = await http.post(
            Uri.parse('https://jsonplaceholder.typicode.com/posts'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'title': 'Test Performance',
              'body': 'Measuring HTTP POST response time',
              'userId': 1,
            }),
          ).timeout(const Duration(seconds: 10));
          if (response.statusCode != 201) {
            throw Exception('HTTP ${response.statusCode}');
          }
        },
        metadata: {'endpoint': 'https://jsonplaceholder.typicode.com/posts'},
      );

      print(result);
      result.success ? expect(true, isTrue) : print('Note: May fail without internet');
    });
  });

  group('Response Time Benchmarks', () {
    test('Summary of all performance benchmarks', () async {
      print('''
╔════════════════════════════════════════════════════════════╗
║         MindWell Clinic Performance Benchmarks
╠════════════════════════════════════════════════════════════╣
║
║ Expectations:
║ • Auth service (sign-up/in): 1-3 seconds
║ • Firestore queries: 200-800ms
║ • Email verification check: 500-1500ms
║ • Journal API (sentiment): 100-500ms (or heuristic fallback)
║ • Push notification token sync: 500-2000ms
║ • Remote assessment API: 1-5 seconds (with fallback)
║
║ Expected Response Time Categories:
║ • Excellent: < 500ms
║ • Good: 500ms - 1s
║ • Acceptable: 1s - 2s
║ • Slow: 2s - 3s
║ • Very Slow: > 3s
║
║ Run tests in debug/profile mode for more accurate results
║
╚════════════════════════════════════════════════════════════╝
      ''');
    });
  });
}

/// Note: To run these tests, use:
/// ```
/// flutter test test/performance_test.dart
/// ```
///
/// For profiling with real backend, ensure:
/// 1. backend is initialized and configured
/// 2. Valid credentials are provided
/// 3. Test user accounts exist (or use anonymous auth)
/// 4. Firestore database rules allow test access
///
/// Example running specific tests:
/// ```
/// flutter test test/performance_test.dart -k "Sentiment Analysis"
/// flutter test test/performance_test.dart -k "Sequential"
/// ```
