import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Represents a performance test result
class PerformanceResult {
  PerformanceResult({
    required this.operationName,
    required this.durationMs,
    required this.success,
    this.errorMessage,
    this.metadata = const {},
  });

  final String operationName;
  final Duration durationMs;
  final bool success;
  final String? errorMessage;
  final Map<String, dynamic> metadata;

  /// Get status indicator (✅ Success, ❌ Failed, ⚠️ Slow)
  String get statusIndicator {
    if (!success) return '❌';
    if (durationMs.inMilliseconds > 3000) return '⚠️ ';
    return '✅';
  }

  /// Get severity level based on response time
  String get speedLevel {
    final ms = durationMs.inMilliseconds;
    if (ms < 500) return 'Excellent';
    if (ms < 1000) return 'Good';
    if (ms < 2000) return 'Acceptable';
    if (ms < 3000) return 'Slow';
    return 'Very Slow';
  }

  @override
  String toString() {
    final status = statusIndicator;
    final time = durationMs.inMilliseconds;
    final error = errorMessage != null ? ' - $errorMessage' : '';
    return '$status $operationName: ${time}ms ($speedLevel)$error';
  }

  Map<String, dynamic> toJson() => {
    'operationName': operationName,
    'durationMs': durationMs.inMilliseconds,
    'success': success,
    'speedLevel': speedLevel,
    'errorMessage': errorMessage,
    'metadata': metadata,
  };
}

/// Represents a test suite result with multiple operations
class PerformanceTestResult {
  PerformanceTestResult({
    required this.testName,
    required this.results,
    required this.totalDuration,
  });

  final String testName;
  final List<PerformanceResult> results;
  final Duration totalDuration;

  /// Calculate statistics
  Duration get averageDuration {
    if (results.isEmpty) return Duration.zero;
    final total = results.fold<int>(0, (sum, r) => sum + r.durationMs.inMilliseconds);
    return Duration(milliseconds: total ~/ results.length);
  }

  int get successCount => results.where((r) => r.success).length;
  int get failureCount => results.where((r) => !r.success).length;
  double get successRate => results.isEmpty ? 0 : (successCount / results.length) * 100;

  /// Get slowest operation
  PerformanceResult? get slowestOperation {
    if (results.isEmpty) return null;
    return results.reduce((a, b) => a.durationMs.inMilliseconds > b.durationMs.inMilliseconds ? a : b);
  }

  /// Get fastest operation
  PerformanceResult? get fastestOperation {
    if (results.isEmpty) return null;
    return results.reduce((a, b) => a.durationMs.inMilliseconds < b.durationMs.inMilliseconds ? a : b);
  }

  String get summary {
    return '''
╔════════════════════════════════════════════════════════════╗
║ Performance Test: $testName
╠════════════════════════════════════════════════════════════╣
║ Total Duration: ${totalDuration.inMilliseconds}ms
║ Total Operations: ${results.length}
║ Success Rate: ${successRate.toStringAsFixed(1)}% ($successCount/${results.length})
║ Average Duration: ${averageDuration.inMilliseconds}ms
║ Fastest: ${fastestOperation?.durationMs.inMilliseconds}ms
║ Slowest: ${slowestOperation?.durationMs.inMilliseconds}ms
╚════════════════════════════════════════════════════════════╝
''';
  }

  void printResults() {
    if (kDebugMode) {
      debugPrint(summary);
      debugPrint('\nDetailed Results:');
      for (final result in results) {
        debugPrint('  $result');
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'testName': testName,
    'totalDurationMs': totalDuration.inMilliseconds,
    'successRate': successRate,
    'averageDurationMs': averageDuration.inMilliseconds,
    'results': results.map((r) => r.toJson()).toList(),
  };

  /// Export as JSON string
  String toJsonString() => jsonEncode(toJson());
}

/// Performance monitoring service for measuring response times
class PerformanceMonitor {
  static const String _logTag = '[PerformanceMonitor]';

  /// Measure the duration of a single async operation
  static Future<PerformanceResult> measure<T>({
    required String operationName,
    required Future<T> Function() operation,
    Map<String, dynamic>? metadata,
  }) async {
    final startTime = DateTime.now();
    try {
      await operation();
      final duration = DateTime.now().difference(startTime);
      if (kDebugMode) {
        debugPrint('$_logTag ✅ $operationName completed in ${duration.inMilliseconds}ms');
      }
      return PerformanceResult(
        operationName: operationName,
        durationMs: duration,
        success: true,
        metadata: metadata ?? {},
      );
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      if (kDebugMode) {
        debugPrint('$_logTag ❌ $operationName failed after ${duration.inMilliseconds}ms: $e');
      }
      return PerformanceResult(
        operationName: operationName,
        durationMs: duration,
        success: false,
        errorMessage: e.toString(),
        metadata: metadata ?? {},
      );
    }
  }

  /// Measure multiple sequential operations and collect results
  static Future<PerformanceTestResult> measureSequential({
    required String testName,
    required List<({String name, Future<void> Function() operation, Map<String, dynamic>? metadata})> operations,
  }) async {
    final testStartTime = DateTime.now();
    final results = <PerformanceResult>[];

    for (final op in operations) {
      final result = await measure(
        operationName: op.name,
        operation: op.operation,
        metadata: op.metadata,
      );
      results.add(result);
    }

    final totalDuration = DateTime.now().difference(testStartTime);
    return PerformanceTestResult(
      testName: testName,
      results: results,
      totalDuration: totalDuration,
    );
  }

  /// Measure multiple parallel operations and collect results
  static Future<PerformanceTestResult> measureParallel({
    required String testName,
    required List<({String name, Future<void> Function() operation, Map<String, dynamic>? metadata})> operations,
  }) async {
    final testStartTime = DateTime.now();
    
    // Run all operations in parallel
    final futures = operations.map((op) => 
      measure(
        operationName: op.name,
        operation: op.operation,
        metadata: op.metadata,
      )
    ).toList();

    final results = await Future.wait(futures);
    final totalDuration = DateTime.now().difference(testStartTime);

    return PerformanceTestResult(
      testName: testName,
      results: results,
      totalDuration: totalDuration,
    );
  }

  /// Run a load test - repeat an operation multiple times
  static Future<PerformanceTestResult> loadTest({
    required String testName,
    required String operationName,
    required int iterations,
    required Future<void> Function() operation,
    bool sequential = false,
  }) async {
    final testStartTime = DateTime.now();
    final results = <PerformanceResult>[];

    if (sequential) {
      // Run sequentially
      for (int i = 0; i < iterations; i++) {
        final result = await measure(
          operationName: '$operationName (${i + 1}/$iterations)',
          operation: operation,
          metadata: {'iteration': i + 1},
        );
        results.add(result);
      }
    } else {
      // Run in parallel
      final futures = <Future<PerformanceResult>>[];
      for (int i = 0; i < iterations; i++) {
        futures.add(
          measure(
            operationName: '$operationName (${i + 1}/$iterations)',
            operation: operation,
            metadata: {'iteration': i + 1},
          ),
        );
      }
      results.addAll(await Future.wait(futures));
    }

    final totalDuration = DateTime.now().difference(testStartTime);
    return PerformanceTestResult(
      testName: testName,
      results: results,
      totalDuration: totalDuration,
    );
  }

  /// Measure response time with timeout protection
  static Future<PerformanceResult> measureWithTimeout<T>({
    required String operationName,
    required Future<T> Function() operation,
    required Duration timeout,
    Map<String, dynamic>? metadata,
  }) async {
    final startTime = DateTime.now();
    try {
      await operation().timeout(timeout, onTimeout: () {
        throw TimeoutException('Operation exceeded $timeout');
      });
      final duration = DateTime.now().difference(startTime);
      if (kDebugMode) {
        debugPrint('$_logTag ✅ $operationName completed in ${duration.inMilliseconds}ms');
      }
      return PerformanceResult(
        operationName: operationName,
        durationMs: duration,
        success: true,
        metadata: {...?metadata, 'timeout': timeout.inMilliseconds},
      );
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      if (kDebugMode) {
        debugPrint('$_logTag ❌ $operationName failed after ${duration.inMilliseconds}ms: $e');
      }
      return PerformanceResult(
        operationName: operationName,
        durationMs: duration,
        success: false,
        errorMessage: e.toString(),
        metadata: {...?metadata, 'timeout': timeout.inMilliseconds},
      );
    }
  }
}
