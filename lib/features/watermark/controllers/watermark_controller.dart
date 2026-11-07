import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:get/get.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/features/camera/models/photo_metadata.dart';
import 'package:gps_camera/features/camera/services/capture_enricher.dart';
import 'package:gps_camera/features/export/services/gallery_export_service.dart';
import 'package:gps_camera/features/watermark/models/watermark_config.dart';
import 'package:gps_camera/features/watermark/models/watermark_content.dart';
import 'package:gps_camera/features/watermark/services/image_processor.dart';
import 'package:gps_camera/features/watermark/services/logo_service.dart';
import 'package:gps_camera/features/watermark/services/watermark_renderer.dart';
import 'package:gps_camera/features/watermark/services/watermark_settings_store.dart';

enum WatermarkEditorStatus { loading, ready, error }

/// Editor state for watermarking one original photo.
class WatermarkController extends GetxController {
  WatermarkController({
    required this.photo,
    required this._storage,
    required this._renderer,
    required this._settings,
    this._processor = const ImageProcessor(),
    this._gallery,
  });

  final File photo;
  final PhotoStorageService _storage;
  final WatermarkRenderer _renderer;
  final WatermarkSettingsStore _settings;
  final ImageProcessor _processor;
  final GalleryExportService? _gallery;

  /// The watermark logo for the preview; null when none is set.
  Rxn<ui.Image> get logo =>
      Get.isRegistered<LogoService>() ? Get.find<LogoService>().image : _noLogo;
  final Rxn<ui.Image> _noLogo = Rxn<ui.Image>();

  /// False when the saved copy should have reached the phone gallery but
  /// did not.
  final RxBool galleryFailed = false.obs;

  final Rx<WatermarkEditorStatus> status = WatermarkEditorStatus.loading.obs;
  final RxnString loadError = RxnString();
  final Rxn<PhotoMetadata> metadata = Rxn<PhotoMetadata>();
  final Rxn<PreviewImage> preview = Rxn<PreviewImage>();

  /// The map stored at capture (Map template), if any.
  final Rxn<ui.Image> mapImage = Rxn<ui.Image>();
  Uint8List? _mapBytes;
  final Rx<WatermarkConfig> config = const WatermarkConfig().obs;
  final RxBool isSaving = false.obs;
  final Rxn<WatermarkResult> lastResult = Rxn<WatermarkResult>();
  final RxnString saveError = RxnString();

  WatermarkContent? get content {
    final current = metadata.value;
    return current == null
        ? null
        : WatermarkContent.from(current, config.value);
  }

  bool get hasAddress => metadata.value?.location.fix?.address != null;

  bool get canSave =>
      status.value == WatermarkEditorStatus.ready &&
      !isSaving.value &&
      !(content?.isEmpty ?? true);

  @override
  void onInit() {
    super.onInit();
    config.value = _settings.load();
    unawaited(load());
  }

  Future<void> load() async {
    status.value = WatermarkEditorStatus.loading;
    loadError.value = null;

    if (_storage.isWatermarkedFile(photo)) {
      _fail(
        'This is a watermarked copy. Open its original to create a new '
        'watermark.',
      );
      return;
    }

    try {
      final results = await Future.wait<Object?>([
        _readMetadata(),
        _processor.loadPreview(photo.path),
      ]);
      metadata.value = results[0]! as PhotoMetadata;
      preview.value = results[1]! as PreviewImage;
      _mapBytes = await CaptureEnricher.storedMap(
        _storage,
        photo,
        metadata.value!,
      );
      final map = _mapBytes;
      mapImage.value = map == null ? null : await decodeMapImage(map);
      status.value = WatermarkEditorStatus.ready;
    } on _LoadException catch (e) {
      _fail(e.message);
    } on ImageProcessingException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('This photo could not be opened.');
    }
  }

  void updateConfig(WatermarkConfig next) {
    if (next == config.value) return;
    config.value = next;
    saveError.value = null;
    lastResult.value = null;
    unawaited(_settings.save(next));
  }

  Future<void> save() async {
    final current = metadata.value;
    final image = preview.value;
    if (!canSave || current == null || image == null) return;

    isSaving.value = true;
    saveError.value = null;
    lastResult.value = null;
    galleryFailed.value = false;
    try {
      final result = await _renderer.render(
        original: photo,
        metadata: current,
        config: config.value,
        imageSize: ui.Size(image.width.toDouble(), image.height.toDouble()),
        mapImage: _mapBytes,
      );
      lastResult.value = result;
      final gallery = _gallery;
      if (gallery != null) {
        try {
          galleryFailed.value = !await gallery.exportEdited(
            result.output,
            takenAt: current.capturedAt,
          );
        } catch (_) {
          galleryFailed.value = true;
        }
      }
    } on WatermarkException catch (e) {
      saveError.value = e.message;
    } catch (_) {
      saveError.value = 'The watermarked copy could not be saved.';
    } finally {
      isSaving.value = false;
    }
  }

  Future<PhotoMetadata> _readMetadata() async {
    final Map<String, dynamic>? json;
    try {
      json = await _storage.readMetadata(photo);
    } on FormatException {
      throw const _LoadException('This photo\'s metadata file is damaged.');
    } on FileSystemException {
      throw const _LoadException('This photo\'s metadata could not be read.');
    }
    if (json == null) {
      throw const _LoadException(
        'This photo has no metadata, so a watermark cannot be created.',
      );
    }
    try {
      return PhotoMetadata.fromJson(json);
    } catch (_) {
      throw const _LoadException('This photo\'s metadata is not recognised.');
    }
  }

  @override
  void onClose() {
    mapImage.value?.dispose();
    super.onClose();
  }

  void _fail(String message) {
    loadError.value = message;
    status.value = WatermarkEditorStatus.error;
  }
}

class _LoadException implements Exception {
  const _LoadException(this.message);

  final String message;
}
