class CaptureFeedback {
  const CaptureFeedback(this.message, {this.isError = false});

  final String message;
  final bool isError;
}
