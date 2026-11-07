import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/features/location/models/gps_accuracy_level.dart';
import 'package:gps_camera/features/watermark/models/watermark_config.dart';
import 'package:gps_camera/features/watermark/models/watermark_content.dart';
import 'package:gps_camera/features/watermark/models/watermark_template.dart';

enum _Role { brand, primary, secondary, notice, poor }

class _Line {
  const _Line(this.text, this.role, {this.label});

  final String text;
  final _Role role;
  final String? label;
}

class _Row {
  _Row(this.value, this.label);

  final TextPainter value;
  final TextPainter? label;

  double get height => math.max(value.height, label?.height ?? 0);
}

/// Lays out and paints a watermark in image pixel coordinates.
///
/// The same painter drives the live preview (scaled to the screen) and the
/// saved output (at full resolution), so both always match. Sizes scale with
/// the image's shorter side, keeping text readable at any resolution.
class WatermarkPainter {
  WatermarkPainter({
    required this.content,
    required this.config,
    required this.imageSize,
    this.mapImage,
    this.reserveMapSlot = false,
  }) {
    _layout();
  }

  /// Map snapshot drawn by the Map template. Without it (and without
  /// [reserveMapSlot]) the template simply has no map column.
  final ui.Image? mapImage;

  /// Leaves the map square empty so a live map widget can sit on top of it
  /// (camera preview). Ignored when there is no location to map.
  final bool reserveMapSlot;

  /// Where the map square is, in image pixels; null when there is none.
  Rect? mapRect;

  static const String brand = 'GPS CAMERA';

  final WatermarkContent content;
  final WatermarkConfig config;
  final Size imageSize;

  /// The area the watermark covers, in image pixels. Empty when there is
  /// nothing to draw.
  Rect bounds = Rect.zero;

  final List<_Row> _rows = [];
  double _unit = 1;
  double _padH = 0;
  double _padV = 0;
  double _gap = 0;
  double _labelWidth = 0;
  double _labelGap = 0;
  double _bar = 0;
  double _radius = 0;
  Color? _background;
  double _mapSide = 0;
  double _mapGap = 0;

  WatermarkTemplate get _template => config.template;

  void paint(Canvas canvas) {
    if (bounds.isEmpty) return;

    final faded = config.opacity < 1;
    if (faded) {
      canvas.saveLayer(
        bounds,
        Paint()..color = Color.fromRGBO(0, 0, 0, config.opacity),
      );
    }

    final panel = RRect.fromRectAndRadius(bounds, Radius.circular(_radius));
    if (_background != null) {
      canvas.drawRRect(panel, Paint()..color = _background!);
    }
    if (_bar > 0) {
      canvas
        ..save()
        ..clipRRect(panel)
        ..drawRect(
          Rect.fromLTWH(bounds.left, bounds.top, _bar, bounds.height),
          Paint()..color = AppColors.accent,
        )
        ..restore();
    }

    final map = mapRect;
    if (map != null) {
      final clip = RRect.fromRectAndRadius(map, Radius.circular(_radius * 0.6));
      final image = mapImage;
      canvas.save();
      canvas.clipRRect(clip);
      if (image != null) {
        final src = _coverSquare(
          image.width.toDouble(),
          image.height.toDouble(),
        );
        canvas.drawImageRect(
          image,
          src,
          map,
          Paint()..filterQuality = FilterQuality.medium,
        );
      } else {
        canvas.drawRect(map, Paint()..color = const Color(0x33FFFFFF));
      }
      canvas.restore();
    }

    final textLeft =
        bounds.left + _bar + _padH + (map == null ? 0 : _mapSide + _mapGap);
    var y = bounds.top + _padV;
    for (final (index, row) in _rows.indexed) {
      if (index > 0) y += _gap;
      final label = row.label;
      if (label != null) {
        label.paint(canvas, Offset(textLeft, y + (row.height - label.height)));
        row.value.paint(
          canvas,
          Offset(
            textLeft + _labelWidth + _labelGap,
            y + (row.height - row.value.height),
          ),
        );
      } else {
        row.value.paint(canvas, Offset(textLeft, y));
      }
      y += row.height;
    }

    if (faded) canvas.restore();
  }

  void dispose() {
    for (final row in _rows) {
      row.value.dispose();
      row.label?.dispose();
    }
    _rows.clear();
  }

  void _layout() {
    final lines = _lines();
    if (lines.isEmpty || imageSize.isEmpty) return;

    final shortSide = math.min(imageSize.width, imageSize.height);
    _unit = shortSide / 1000 * config.textSize.scale;
    final margin = shortSide * 0.035;

    switch (_template) {
      case WatermarkTemplate.classic:
        _padH = 20 * _unit;
        _padV = 16 * _unit;
        _gap = 5 * _unit;
        _radius = 12 * _unit;
        _background = const Color(0x8C000000);
      case WatermarkTemplate.professional:
        _padH = 22 * _unit;
        _padV = 18 * _unit;
        _gap = 7 * _unit;
        _radius = 8 * _unit;
        _bar = 7 * _unit;
        _labelGap = 14 * _unit;
        _background = AppColors.viewfinderBackground.withValues(alpha: 0.82);
      case WatermarkTemplate.minimal:
        _padH = 6 * _unit;
        _padV = 6 * _unit;
        _gap = 3 * _unit;
      case WatermarkTemplate.map:
        _padH = 16 * _unit;
        _padV = 14 * _unit;
        _gap = 4 * _unit;
        _radius = 12 * _unit;
        _background = const Color(0xB3000000);
    }
    final withMap =
        _template == WatermarkTemplate.map &&
        content.canShowMap &&
        (mapImage != null || reserveMapSlot);
    if (withMap) {
      _mapSide = 190 * _unit;
      _mapGap = 14 * _unit;
    }

    final maxBlockWidth = imageSize.width - margin * 2;
    final labels = [
      for (final line in lines)
        if (line.label != null)
          _text(line.label!, _labelStyle(), maxBlockWidth),
    ];
    _labelWidth = labels.fold(0, (w, p) => math.max(w, p.width));
    final labelColumn = _labelWidth == 0 ? 0 : _labelWidth + _labelGap;

    final chrome = _bar + _padH * 2 + (withMap ? _mapSide + _mapGap : 0);
    var labelIndex = 0;
    for (final line in lines) {
      final label = line.label == null ? null : labels[labelIndex++];
      final maxValueWidth = math.max(
        1.0,
        maxBlockWidth - chrome - (label == null ? 0 : labelColumn),
      );
      _rows.add(
        _Row(_text(line.text, _style(line.role), maxValueWidth), label),
      );
    }

    var contentWidth = 0.0;
    var contentHeight = 0.0;
    for (final (index, row) in _rows.indexed) {
      final width = row.label == null
          ? row.value.width
          : labelColumn + row.value.width;
      contentWidth = math.max(contentWidth, width);
      contentHeight += row.height + (index > 0 ? _gap : 0);
    }

    final width = math.min(contentWidth + chrome, maxBlockWidth);
    final height = math.max(contentHeight, withMap ? _mapSide : 0) + _padV * 2;
    final left = switch (config.position) {
      WatermarkPosition.bottomLeft => margin,
      WatermarkPosition.bottomCenter => (imageSize.width - width) / 2,
      WatermarkPosition.bottomRight => imageSize.width - margin - width,
    };
    final top = math.max(0.0, imageSize.height - margin - height);
    bounds = Rect.fromLTWH(left, top, width, height);
    if (withMap) {
      mapRect = Rect.fromLTWH(
        left + _padH,
        top + (height - _mapSide) / 2,
        _mapSide,
        _mapSide,
      );
    }
  }

  List<_Line> _lines() {
    final c = content;
    if (c.isEmpty) return const [];

    return switch (_template) {
      WatermarkTemplate.classic => [
        const _Line(brand, _Role.brand),
        if (c.dateTimeLine != null) _Line(c.dateTimeLine!, _Role.primary),
        if (c.locationNotice != null) _Line(c.locationNotice!, _Role.notice),
        if (c.coordinatesLine != null)
          _Line(c.coordinatesLine!, _Role.secondary),
        if (c.accuracyValue != null)
          _Line('GPS Accuracy: ${c.accuracyValue}', _accuracyRole),
        if (c.address != null) _Line(c.address!, _Role.secondary),
      ],
      WatermarkTemplate.professional => [
        const _Line(brand, _Role.brand),
        if (c.date != null) _Line(c.date!, _Role.primary, label: 'DATE'),
        if (c.time != null)
          _Line('${c.time}  ${c.timeZone}', _Role.secondary, label: 'TIME'),
        if (c.locationNotice != null) _Line(c.locationNotice!, _Role.notice),
        if (c.latitude != null)
          _Line(c.latitude!, _Role.secondary, label: 'LAT'),
        if (c.longitude != null)
          _Line(c.longitude!, _Role.secondary, label: 'LON'),
        if (c.accuracy != null)
          _Line(
            '${c.accuracy}  ·  ${_levelLabel(c.accuracyLevel)}',
            _accuracyRole,
            label: 'ACC',
          ),
        if (c.address != null)
          _Line(c.address!, _Role.secondary, label: 'ADDR'),
      ],
      WatermarkTemplate.map => [
        const _Line(brand, _Role.brand),
        if (c.placeTitle != null)
          _Line(
            c.flag == null ? c.placeTitle! : '${c.placeTitle}  ${c.flag}',
            _Role.primary,
          ),
        if (c.locationNotice != null) _Line(c.locationNotice!, _Role.notice),
        if (c.address != null) _Line(c.address!, _Role.secondary),
        if (c.coordinatesLine != null)
          _Line(c.coordinatesLine!, _Role.secondary),
        if (c.dateTimeLine != null)
          _Line(c.dateTimeLine!.replaceAll('  |  ', '  ·  '), _Role.secondary),
        if (c.accuracyValue != null)
          _Line('GPS Accuracy: ${c.accuracyValue}', _accuracyRole),
        if (c.plusCode != null)
          _Line('Plus Code ${c.plusCode}', _Role.secondary),
      ],
      WatermarkTemplate.minimal => [
        if (c.dateTimeLine != null)
          _Line(c.dateTimeLine!.replaceAll('  |  ', '  ·  '), _Role.primary),
        if (c.locationNotice != null) _Line(c.locationNotice!, _Role.notice),
        if (c.coordinatesLine != null || c.accuracyValue != null)
          _Line(
            [?c.coordinatesLine, ?c.accuracyValue].join('  ·  '),
            _accuracyRole == _Role.poor && c.coordinatesLine == null
                ? _Role.poor
                : _Role.secondary,
          ),
        if (c.address != null) _Line(c.address!, _Role.secondary),
      ],
    };
  }

  _Role get _accuracyRole => content.accuracyLevel == GpsAccuracyLevel.poor
      ? _Role.poor
      : _Role.secondary;

  static String _levelLabel(GpsAccuracyLevel? level) => switch (level) {
    GpsAccuracyLevel.good => 'Good',
    GpsAccuracyLevel.moderate => 'Moderate',
    GpsAccuracyLevel.poor || null => 'Poor',
  };

  TextStyle _style(_Role role) {
    final minimal = _template == WatermarkTemplate.minimal;
    final (size, weight, color) = switch ((_template, role)) {
      (_, _Role.brand) => (15.0, FontWeight.w700, AppColors.accent),
      (WatermarkTemplate.professional, _Role.primary) => (
        27.0,
        FontWeight.w600,
        AppColors.onViewfinder,
      ),
      (WatermarkTemplate.minimal, _Role.primary) => (
        21.0,
        FontWeight.w600,
        AppColors.onViewfinder,
      ),
      (_, _Role.primary) => (26.0, FontWeight.w600, AppColors.onViewfinder),
      (WatermarkTemplate.minimal, _)
          when role != _Role.notice && role != _Role.poor =>
        (19.0, FontWeight.w500, AppColors.onViewfinder),
      (_, _Role.secondary) => (21.0, FontWeight.w400, AppColors.onViewfinder),
      (_, _Role.notice) => (
        minimal ? 18.0 : 19.0,
        FontWeight.w600,
        AppColors.accent,
      ),
      (_, _Role.poor) => (
        minimal ? 19.0 : 21.0,
        FontWeight.w600,
        AppColors.errorDark,
      ),
    };

    return TextStyle(
      fontSize: size * _unit,
      fontWeight: weight,
      color: color,
      height: 1.25,
      letterSpacing: role == _Role.brand ? 2.4 * _unit : 0.1 * _unit,
      fontFeatures: const [ui.FontFeature.tabularFigures()],
      shadows: minimal
          ? [
              Shadow(
                color: const Color(0xCC000000),
                blurRadius: 4 * _unit,
                offset: Offset(0, _unit),
              ),
            ]
          : null,
    );
  }

  /// Centre square of an image, so maps fill the square without stretching.
  static Rect _coverSquare(double width, double height) {
    final side = math.min(width, height);
    return Rect.fromLTWH((width - side) / 2, (height - side) / 2, side, side);
  }

  TextStyle _labelStyle() => TextStyle(
    fontSize: 15 * _unit,
    fontWeight: FontWeight.w700,
    color: AppColors.onViewfinderMuted,
    letterSpacing: 1.4 * _unit,
    height: 1.25,
  );

  static TextPainter _text(String text, TextStyle style, double maxWidth) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
  }
}
