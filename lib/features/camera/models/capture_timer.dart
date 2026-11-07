/// Delay between pressing the shutter and taking the photo.
enum CaptureTimer {
  off(0, 'Timer off'),
  three(3, '3 s'),
  ten(10, '10 s');

  const CaptureTimer(this.seconds, this.label);

  final int seconds;
  final String label;

  CaptureTimer get next => values[(index + 1) % values.length];

  static CaptureTimer parse(String? name) =>
      values.firstWhere((t) => t.name == name, orElse: () => CaptureTimer.off);
}
