enum LocationStatus {
  /// Tracking has not been started yet.
  idle,

  /// Permission granted and services on, waiting for the first fix.
  acquiring,

  /// Receiving fixes. Check staleness and accuracy separately.
  ready,
  permissionDenied,
  permissionBlocked,
  serviceDisabled,

  /// No fix arrived in time, or the platform reported an error.
  unavailable,
}
