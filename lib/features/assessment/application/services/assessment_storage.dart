import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/models/assessment.dart';
import '../adapters/assessment_result_adapter.dart';

/// 问卷历史记录存储服务
/// 使用 Hive 数据库持久化存储 PHQ-9 和 GAD-7 的历史记录
class AssessmentStorage {
  static const String _boxName = 'assessment_history_box';
  static const String _phq9HistoryKey = 'phq9_history';
  static const String _gad7HistoryKey = 'gad7_history';
  
  static Box? _box;
  static bool _initialized = false;

  /// 初始化 Hive 数据库
  /// 必须在应用启动时调用一次
  static Future<void> init() async {
    if (_initialized) return;
    
    try {
      // 注册 TypeAdapter
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(AssessmentResultAdapter());
      }
      
      // 打开或创建 Hive box
      // 对于 Web 平台，使用相同的 box 名称确保数据持久化
      _box = await Hive.openBox(_boxName);
      _initialized = true;
      
      // 验证 box 是否已打开
      if (_box != null && _box!.isOpen) {
        debugPrint('✓ Hive 数据库初始化成功，box: $_boxName');
        // 检查是否有现有数据
        final phq9Count = (_box!.get(_phq9HistoryKey) as List?)?.length ?? 0;
        final gad7Count = (_box!.get(_gad7HistoryKey) as List?)?.length ?? 0;
        debugPrint('✓ 现有数据: PHQ-9=$phq9Count 条, GAD-7=$gad7Count 条');
      } else {
        debugPrint('✗ Hive box 未正确打开');
      }
    } catch (e) {
      debugPrint('✗ Hive 数据库初始化失败: $e');
      rethrow;
    }
  }

  /// 确保数据库已初始化
  static Future<void> _ensureInitialized() async {
    if (!_initialized || _box == null) {
      await init();
    }
  }

  /// 保存 PHQ-9 历史记录
  static Future<void> savePhq9History(List<AssessmentResult> history) async {
    try {
      await _ensureInitialized();
      await _box!.put(_phq9HistoryKey, history);
      // 强制同步到磁盘（Web 平台使用 IndexedDB）
      await _box!.flush();
      debugPrint('✓ 保存 PHQ-9 历史记录: ${history.length} 条');
      // 验证保存是否成功
      final saved = _box!.get(_phq9HistoryKey);
      if (saved != null) {
        final savedList = (saved as List).cast<AssessmentResult>().toList();
        debugPrint('✓ 验证保存成功: ${savedList.length} 条记录');
      }
    } catch (e) {
      debugPrint('✗ 保存 PHQ-9 历史记录失败: $e');
      rethrow;
    }
  }

  /// 保存 GAD-7 历史记录
  static Future<void> saveGad7History(List<AssessmentResult> history) async {
    try {
      await _ensureInitialized();
      await _box!.put(_gad7HistoryKey, history);
      // 强制同步到磁盘（Web 平台使用 IndexedDB）
      await _box!.flush();
      debugPrint('✓ 保存 GAD-7 历史记录: ${history.length} 条');
      // 验证保存是否成功
      final saved = _box!.get(_gad7HistoryKey);
      if (saved != null) {
        final savedList = (saved as List).cast<AssessmentResult>().toList();
        debugPrint('✓ 验证保存成功: ${savedList.length} 条记录');
      }
    } catch (e) {
      debugPrint('✗ 保存 GAD-7 历史记录失败: $e');
      rethrow;
    }
  }

  /// 加载 PHQ-9 历史记录
  static Future<List<AssessmentResult>> loadPhq9History() async {
    try {
      await _ensureInitialized();
      if (!_box!.isOpen) {
        debugPrint('✗ Hive box 未打开，尝试重新打开');
        _box = await Hive.openBox(_boxName);
      }
      
      final history = _box!.get(_phq9HistoryKey);
      if (history == null) {
        debugPrint('✓ 加载 PHQ-9 历史记录: 无数据');
        return [];
      }
      
      final results = (history as List).cast<AssessmentResult>().toList();
      debugPrint('✓ 加载 PHQ-9 历史记录: ${results.length} 条');
      // 打印详细信息用于调试
      for (var i = 0; i < results.length && i < 3; i++) {
        final r = results[i];
        debugPrint('  记录 ${i + 1}: score=${r.score}, severity=${r.severity}, at=${r.at.toIso8601String()}');
      }
      return results;
    } catch (e) {
      debugPrint('✗ 加载 PHQ-9 历史记录失败: $e');
      debugPrint('错误堆栈: ${StackTrace.current}');
      return [];
    }
  }

  /// 加载 GAD-7 历史记录
  static Future<List<AssessmentResult>> loadGad7History() async {
    try {
      await _ensureInitialized();
      if (!_box!.isOpen) {
        debugPrint('✗ Hive box 未打开，尝试重新打开');
        _box = await Hive.openBox(_boxName);
      }
      
      final history = _box!.get(_gad7HistoryKey);
      if (history == null) {
        debugPrint('✓ 加载 GAD-7 历史记录: 无数据');
        return [];
      }
      
      final results = (history as List).cast<AssessmentResult>().toList();
      debugPrint('✓ 加载 GAD-7 历史记录: ${results.length} 条');
      // 打印详细信息用于调试
      for (var i = 0; i < results.length && i < 3; i++) {
        final r = results[i];
        debugPrint('  记录 ${i + 1}: score=${r.score}, severity=${r.severity}, at=${r.at.toIso8601String()}');
      }
      return results;
    } catch (e) {
      debugPrint('✗ 加载 GAD-7 历史记录失败: $e');
      debugPrint('错误堆栈: ${StackTrace.current}');
      return [];
    }
  }

  /// 保存完整历史记录（PHQ-9 和 GAD-7）
  static Future<void> saveHistory({
    required List<AssessmentResult> phq9History,
    required List<AssessmentResult> gad7History,
  }) async {
    try {
      debugPrint('>>> AssessmentStorage.saveHistory 开始: PHQ-9=${phq9History.length}, GAD-7=${gad7History.length}');
      await Future.wait([
        savePhq9History(phq9History),
        saveGad7History(gad7History),
      ]);
      debugPrint('>>> AssessmentStorage.saveHistory 完成');
    } catch (e) {
      debugPrint('>>> AssessmentStorage.saveHistory 失败: $e');
      rethrow;
    }
  }

  /// 加载完整历史记录（PHQ-9 和 GAD-7）
  static Future<({
    List<AssessmentResult> phq9History,
    List<AssessmentResult> gad7History,
  })> loadHistory() async {
    final results = await Future.wait([
      loadPhq9History(),
      loadGad7History(),
    ]);
    return (
      phq9History: results[0],
      gad7History: results[1],
    );
  }
}

