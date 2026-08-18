import 'package:flutter_application_mhproj/models/assessment.dart';

/// Represents a message that is being streamed in real-time
class StreamingMessage {
  StreamingMessage({
    required this.role,
    this.text = '',
    this.isComplete = false,
    this.error,
  });

  final AgentRole role;
  String text;
  bool isComplete;
  String? error;

  void appendChunk(String chunk) {
    text += chunk;
  }

  void complete() {
    isComplete = true;
  }

  void setError(String errorMessage) {
    error = errorMessage;
    isComplete = true;
  }

  AssessmentMessage toAssessmentMessage() {
    return AssessmentMessage(
      role: role,
      text: text,
      meta: error != null ? {'error': error} : null,
    );
  }
}
