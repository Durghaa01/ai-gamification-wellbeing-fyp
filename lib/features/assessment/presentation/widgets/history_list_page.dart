import 'package:flutter/material.dart';
import '../../domain/models/assessment.dart';
import '../../application/services/assessment_storage.dart';

/// 历史记录列表页面
/// 显示所有 PHQ-9 和 GAD-7 的问卷历史记录
class HistoryListPage extends StatefulWidget {
  const HistoryListPage({super.key});

  @override
  State<HistoryListPage> createState() => _HistoryListPageState();
}

class _HistoryListPageState extends State<HistoryListPage> {
  List<AssessmentResult> _phq9History = [];
  List<AssessmentResult> _gad7History = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    try {
      final history = await AssessmentStorage.loadHistory();
      setState(() {
        _phq9History = history.phq9History;
        _gad7History = history.gad7History;
        _loading = false;
      });
    } catch (e) {
      debugPrint('加载历史记录失败: $e');
      setState(() => _loading = false);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
           '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _severityLabel(String severity, bool isPhq9) {
    switch (severity) {
      case 'minimal':
        return 'Minimal';
      case 'mild':
        return 'Mild';
      case 'moderate':
        return 'Moderate';
      case 'moderately_severe':
        return isPhq9 ? 'Moderately severe' : 'Severe';
      case 'severe':
        return 'Severe';
      default:
        return severity.isEmpty ? '-' : severity;
    }
  }

  Color _severityColor(String severity, bool isPhq9) {
    switch (severity) {
      case 'minimal':
        return Colors.green;
      case 'mild':
        return Colors.lightGreen;
      case 'moderate':
        return Colors.orange;
      case 'moderately_severe':
        return isPhq9 ? Colors.deepOrange : Colors.red;
      case 'severe':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildHistoryCard(AssessmentResult result, bool isPhq9) {
    final maxScore = isPhq9 ? 27 : 21;
    final scorePercent = result.score / maxScore;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isPhq9 ? 'PHQ‑9' : 'GAD‑7',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _formatDate(result.at),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Score: ${result.score} / $maxScore',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Severity: ${_severityLabel(result.severity, isPhq9)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _severityColor(result.severity, isPhq9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: scorePercent,
                minHeight: 8,
                color: _severityColor(result.severity, isPhq9),
                backgroundColor: Colors.grey[300],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allHistory = [
      ..._phq9History.map((e) => (isPhq9: true, result: e)),
      ..._gad7History.map((e) => (isPhq9: false, result: e)),
    ];
    allHistory.sort((a, b) => b.result.at.compareTo(a.result.at)); // 最新的在前

    return Scaffold(
      appBar: AppBar(
        title: const Text('Questionnaire History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : allHistory.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No history yet',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Complete a questionnaire to see your history',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: allHistory.length,
                    itemBuilder: (context, index) {
                      final item = allHistory[index];
                      return _buildHistoryCard(item.result, item.isPhq9);
                    },
                  ),
                ),
    );
  }
}

