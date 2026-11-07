/// UI quality bands for horizontal accuracy. These describe the reported
/// estimate, not a guarantee of real-world precision.
enum GpsAccuracyLevel {
  good,
  moderate,
  poor;

  static const double goodMaxMeters = 10;
  static const double moderateMaxMeters = 30;

  static GpsAccuracyLevel fromMeters(double meters) {
    if (meters <= goodMaxMeters) return GpsAccuracyLevel.good;
    if (meters <= moderateMaxMeters) return GpsAccuracyLevel.moderate;
    return GpsAccuracyLevel.poor;
  }
}
