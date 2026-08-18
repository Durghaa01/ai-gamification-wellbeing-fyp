/// Result of sending a message with retry capabilities
class MessageSendResult {
  const MessageSendResult({
    required this.success,
    this.error,
    this.canRetry = false,
    this.retryCount = 0,
  });

  final bool success;
  final String? error;
  final bool canRetry;
  final int retryCount;

  factory MessageSendResult.success() {
    return const MessageSendResult(success: true);
  }

  factory MessageSendResult.failure({
    required String error,
    bool canRetry = true,
    int retryCount = 0,
  }) {
    return MessageSendResult(
      success: false,
      error: error,
      canRetry: canRetry,
      retryCount: retryCount,
    );
  }

  factory MessageSendResult.guestLimitReached() {
    return const MessageSendResult(
      success: false,
      error: 'Guest message limit reached',
      canRetry: false,
    );
  }

  MessageSendResult withIncrementedRetry() {
    return MessageSendResult(
      success: false,
      error: error,
      canRetry: canRetry,
      retryCount: retryCount + 1,
    );
  }
}
