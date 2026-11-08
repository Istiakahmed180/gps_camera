/// What the shutter does: take a photo or record a video.
enum CaptureMode {
  photo,
  video;

  bool get isVideo => this == video;
}
