import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show IconData, Icons;
import 'package:flutter/painting.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/core/utils/script.dart';
import 'package:gps_camera/features/location/models/gps_accuracy_level.dart';
import 'package:gps_camera/features/watermark/models/watermark_config.dart';
import 'package:gps_camera/features/watermark/models/watermark_content.dart';
import 'package:gps_camera/features/watermark/models/watermark_template.dart';

enum _Role { brand, custom, primary, secondary, note, notice, poor }

class _Line {
  const _Line(
    this.text,
    this.role, {
    this.label,
    this.withLogo = false,
    this.icon,
  });

  final String text;
  final _Role role;
  final String? label;

  /// Small symbol drawn before the text (card templates).
  final IconData? icon;

  /// The logo is drawn at the start of this line.
  final bool withLogo;
}

class _Row {
  _Row(
    this.value,
    this.label, {
    this.logoSide = 0,
    this.logoGap = 0,
    this.icon,
  });

  final TextPainter value;
  final TextPainter? label;

  /// Size of the logo square at the start of the row; 0 for none.
  final double logoSide;

  /// Space after the logo or icon.
  final double logoGap;

  /// The line's icon, drawn where a logo would be.
  final TextPainter? icon;

  /// Width taken before the text by the logo or icon.
  double get logoWidth => logoSide > 0
      ? logoSide + logoGap
      : icon == null
      ? 0
      : icon!.width + logoGap;

  double get height =>
      math.max(math.max(value.height, label?.height ?? 0), logoSide);

  void dispose() {
    value.dispose();
    label?.dispose();
    icon?.dispose();
  }
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
    this.logoImage,
    bool? rtl,
  }) : rtl = rtl ?? isRtlLanguage() {
    _layout();
  }

  /// Lays the watermark out right to left (Arabic): text right-aligned,
  /// map, logo, labels and accent bar on the right.
  final bool rtl;

  /// Whether the app's current language is written right to left.
  static bool isRtlLanguage() => Get.locale?.languageCode == 'ar';

  /// [x]..[x]+[width] mirrored inside [bounds] when [rtl].
  double _x(double x, double width) =>
      rtl ? bounds.left + bounds.right - x - width : x;

  /// The user's logo, drawn beside the heading when [WatermarkConfig.showLogo]
  /// is on. Ignored by the Minimal template.
  final ui.Image? logoImage;

  /// Map snapshot drawn by the Map template. Without it (and without
  /// [reserveMapSlot]) the template simply has no map column.
  final ui.Image? mapImage;

  /// Leaves the map square empty so a live map widget can sit on top of it
  /// (camera preview). Ignored when there is no location to map.
  final bool reserveMapSlot;

  /// Where the map square is, in image pixels; null when there is none.
  Rect? mapRect;

  /// The map is drawn as a circle inside [mapRect].
  bool get mapIsRound => config.template.roundMapShape;

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
          Rect.fromLTWH(_x(bounds.left, _bar), bounds.top, _bar, bounds.height),
          Paint()..color = AppColors.accent,
        )
        ..restore();
    }

    final map = mapRect;
    if (map != null) {
      final image = mapImage;
      canvas.save();
      if (mapIsRound) {
        canvas.clipPath(Path()..addOval(map));
      } else {
        canvas.clipRRect(
          RRect.fromRectAndRadius(map, Radius.circular(_radius * 0.6)),
        );
      }
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

    // Positions are worked out left to right, then mirrored by [_x].
    final textLeft =
        bounds.left +
        _bar +
        _padH +
        (map == null || _template.mapAtEnd ? 0 : _mapSide + _mapGap);
    var y = bounds.top + _padV;
    for (final (index, row) in _rows.indexed) {
      if (index > 0) y += _gap;
      final label = row.label;
      if (label != null) {
        label.paint(
          canvas,
          Offset(_x(textLeft, label.width), y + (row.height - label.height)),
        );
        row.value.paint(
          canvas,
          Offset(
            _x(textLeft + _labelWidth + _labelGap, row.value.width),
            y + (row.height - row.value.height),
          ),
        );
      } else {
        final icon = row.icon;
        if (icon != null) {
          // Centred on the first line, so it stays put when text wraps.
          final lineHeight = row.value.preferredLineHeight;
          icon.paint(
            canvas,
            Offset(
              _x(textLeft, icon.width),
              y + math.max(0.0, (lineHeight - icon.height) / 2),
            ),
          );
        }
        final logo = logoImage;
        if (row.logoSide > 0 && logo != null) {
          final box = Rect.fromLTWH(
            _x(textLeft, row.logoSide),
            y + (row.height - row.logoSide) / 2,
            row.logoSide,
            row.logoSide,
          );
          canvas.drawImageRect(
            logo,
            Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
            _fitInside(logo, box),
            Paint()..filterQuality = FilterQuality.medium,
          );
        }
        row.value.paint(
          canvas,
          Offset(
            _x(textLeft + row.logoWidth, row.value.width),
            icon == null ? y + (row.height - row.value.height) / 2 : y,
          ),
        );
      }
      y += row.height;
    }

    if (faded) canvas.restore();
  }

  void dispose() {
    for (final row in _rows) {
      row.dispose();
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
      case WatermarkTemplate.mapCard ||
          WatermarkTemplate.roundMap ||
          WatermarkTemplate.mapRight ||
          WatermarkTemplate.banner:
        _padH = 18 * _unit;
        _padV = 16 * _unit;
        _gap = 5 * _unit;
        _radius = 14 * _unit;
        _background = const Color(0xD90B0F14);
    }
    final withMap =
        _template.showsMap &&
        content.canShowMap &&
        (mapImage != null || reserveMapSlot);
    if (withMap) {
      _mapSide = 190 * _unit;
      _mapGap = 14 * _unit;
    }

    final maxBlockWidth = imageSize.width - margin * 2;
    var size = _buildRows(lines, maxBlockWidth, withMap);
    if (withMap && _template.isCard) {
      // The map is as tall as the text beside it, within limits.
      final side = size.height.clamp(150 * _unit, 240 * _unit).toDouble();
      if ((side - _mapSide).abs() > _unit) {
        _mapSide = side;
        dispose();
        size = _buildRows(lines, maxBlockWidth, withMap);
      }
    }

    final chrome = _bar + _padH * 2 + (withMap ? _mapSide + _mapGap : 0);
    final width = _template.isCard
        ? maxBlockWidth
        : math.min(size.width + chrome, maxBlockWidth);
    final height = math.max(size.height, withMap ? _mapSide : 0) + _padV * 2;
    final left = _template.isCard
        ? margin
        : switch (config.position) {
            WatermarkPosition.bottomLeft => margin,
            WatermarkPosition.bottomCenter => (imageSize.width - width) / 2,
            WatermarkPosition.bottomRight => imageSize.width - margin - width,
          };
    final top = math.max(0.0, imageSize.height - margin - height);
    bounds = Rect.fromLTWH(left, top, width, height);
    if (withMap) {
      final mapLeft = _template.mapAtEnd
          ? left + width - _padH - _mapSide
          : left + _padH;
      mapRect = Rect.fromLTWH(
        _x(mapLeft, _mapSide),
        top + (height - _mapSide) / 2,
        _mapSide,
        _mapSide,
      );
    }
  }

  /// Lays out every line; returns the text block's size.
  Size _buildRows(List<_Line> lines, double maxBlockWidth, bool withMap) {
    final labels = [
      for (final line in lines)
        if (line.label != null)
          _text(
            line.label!,
            _spaced(_labelStyle(), line.label!),
            maxBlockWidth,
          ),
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
      final style = _style(line.role);
      final icon = line.icon == null
          ? null
          : _icon(line.icon!, style.fontSize! * 0.95, style.color!);
      final logoSide = line.withLogo ? 36 * _unit : 0.0;
      final logoGap = (line.withLogo && line.text.isNotEmpty) || icon != null
          ? 10 * _unit
          : 0.0;
      final lead = logoSide > 0 ? logoSide : icon?.width ?? 0;
      _rows.add(
        _Row(
          _text(
            line.text,
            _spaced(style, line.text),
            math.max(1.0, maxValueWidth - lead - logoGap),
          ),
          label,
          logoSide: logoSide,
          logoGap: logoGap,
          icon: icon,
        ),
      );
    }

    var contentWidth = 0.0;
    var contentHeight = 0.0;
    for (final (index, row) in _rows.indexed) {
      final width = row.label == null
          ? row.logoWidth + row.value.width
          : labelColumn + row.value.width;
      contentWidth = math.max(contentWidth, width);
      contentHeight += row.height + (index > 0 ? _gap : 0);
    }
    return Size(contentWidth, contentHeight);
  }

  List<_Line> _lines() {
    final c = content;
    if (c.isEmpty) return const [];

    return switch (_template) {
      WatermarkTemplate.classic => [
        ..._header(),
        if (c.dateTimeLine != null) _Line(c.dateTimeLine!, _Role.primary),
        if (c.locationNotice != null) _Line(c.locationNotice!, _Role.notice),
        if (_coordinatesAndAltitude != null)
          _Line(_coordinatesAndAltitude!, _Role.secondary),
        if (c.accuracyValue != null)
          _Line(
            'GPS Accuracy: @value'.trParams({'value': '${c.accuracyValue}'}),
            _accuracyRole,
          ),
        if (c.direction != null)
          _Line(
            'Facing @direction'.trParams({'direction': '${c.direction}'}),
            _Role.secondary,
          ),
        if (c.address != null) _Line(c.address!, _Role.secondary),
        if (c.note != null)
          _Line('Note: @note'.trParams({'note': '${c.note}'}), _Role.note),
      ],
      WatermarkTemplate.professional => [
        ..._header(),
        if (c.date != null) _Line(c.date!, _Role.primary, label: 'DATE'.tr),
        if (c.time != null)
          _Line('${c.time}  ${c.timeZone}', _Role.secondary, label: 'TIME'.tr),
        if (c.locationNotice != null) _Line(c.locationNotice!, _Role.notice),
        if (c.latitude != null)
          _Line(c.latitude!, _Role.secondary, label: 'LAT'.tr),
        if (c.longitude != null)
          _Line(c.longitude!, _Role.secondary, label: 'LON'.tr),
        if (c.altitude != null)
          _Line(c.altitude!, _Role.secondary, label: 'ALT'.tr),
        if (c.accuracy != null)
          _Line(
            '${c.accuracy}  ·  ${_levelLabel(c.accuracyLevel)}',
            _accuracyRole,
            label: 'ACC'.tr,
          ),
        if (c.direction != null)
          _Line(c.direction!, _Role.secondary, label: 'DIR'.tr),
        if (c.address != null)
          _Line(c.address!, _Role.secondary, label: 'ADDR'.tr),
        if (c.note != null) _Line(c.note!, _Role.note, label: 'NOTE'.tr),
      ],
      WatermarkTemplate.map => [
        ..._header(),
        if (c.placeTitle != null)
          _Line(
            c.flag == null ? c.placeTitle! : '${c.placeTitle}  ${c.flag}',
            _Role.primary,
          ),
        if (c.locationNotice != null) _Line(c.locationNotice!, _Role.notice),
        if (c.address != null) _Line(c.address!, _Role.secondary),
        if (_coordinatesAndAltitude != null)
          _Line(_coordinatesAndAltitude!, _Role.secondary),
        if (c.dateTimeLine != null)
          _Line(c.dateTimeLine!.replaceAll('  |  ', '  ·  '), _Role.secondary),
        if (c.accuracyValue != null)
          _Line(
            'GPS Accuracy: @value'.trParams({'value': '${c.accuracyValue}'}),
            _accuracyRole,
          ),
        if (c.direction != null)
          _Line(
            'Facing @direction'.trParams({'direction': '${c.direction}'}),
            _Role.secondary,
          ),
        if (c.plusCode != null)
          _Line(
            'Plus Code @code'.trParams({'code': '${c.plusCode}'}),
            _Role.secondary,
          ),
        if (c.note != null)
          _Line('Note: @note'.trParams({'note': '${c.note}'}), _Role.note),
      ],
      WatermarkTemplate.minimal => [
        if (c.customText != null) _Line(c.customText!, _Role.custom),
        if (c.dateTimeLine != null)
          _Line(c.dateTimeLine!.replaceAll('  |  ', '  ·  '), _Role.primary),
        if (c.locationNotice != null) _Line(c.locationNotice!, _Role.notice),
        if (_coordinatesAndAltitude != null || c.accuracyValue != null)
          _Line(
            [?_coordinatesAndAltitude, ?c.accuracyValue].join('  ·  '),
            _accuracyRole == _Role.poor && c.coordinatesLine == null
                ? _Role.poor
                : _Role.secondary,
          ),
        if (c.direction != null)
          _Line(
            'Facing @direction'.trParams({'direction': '${c.direction}'}),
            _Role.secondary,
          ),
        if (c.address != null) _Line(c.address!, _Role.secondary),
        if (c.note != null) _Line(c.note!, _Role.note),
      ],
      WatermarkTemplate.mapCard ||
      WatermarkTemplate.roundMap ||
      WatermarkTemplate.mapRight ||
      WatermarkTemplate.banner => _cardLines(),
    };
  }

  /// Place name as the title, then one detail per line with an icon.
  List<_Line> _cardLines() {
    final c = content;
    final facing = c.direction == null
        ? null
        : 'Facing @direction'.trParams({'direction': '${c.direction}'});
    final accuracy = c.accuracyValue == null
        ? null
        : 'GPS Accuracy: @value'.trParams({'value': '${c.accuracyValue}'});
    return [
      ..._header(),
      if (c.placeTitle != null)
        _Line(
          c.flag == null ? c.placeTitle! : '${c.placeTitle}  ${c.flag}',
          _Role.primary,
        ),
      if (c.locationNotice != null) _Line(c.locationNotice!, _Role.notice),
      if (c.address != null)
        _Line(c.address!, _Role.secondary, icon: Icons.place_outlined),
      if (c.dateTimeLine != null)
        _Line(
          c.dateTimeLine!.replaceAll('  |  ', '  ·  '),
          _Role.secondary,
          icon: Icons.schedule_rounded,
        ),
      if (_coordinatesAndAltitude != null)
        _Line(
          _coordinatesAndAltitude!,
          _Role.secondary,
          icon: Icons.my_location_rounded,
        ),
      if (accuracy != null || facing != null)
        _Line(
          [?accuracy, ?facing].join('  ·  '),
          accuracy == null ? _Role.secondary : _accuracyRole,
          icon: Icons.explore_outlined,
        ),
      if (c.note != null)
        _Line(c.note!, _Role.note, icon: Icons.sticky_note_2_outlined),
    ];
  }

  /// `23.910908° N, 90.401005° E  ·  Alt 34 m`
  String? get _coordinatesAndAltitude {
    final parts = [?content.coordinatesLine, ?content.altitudeLine];
    return parts.isEmpty ? null : parts.join('  ·  ');
  }

  /// [icon] as text, so it scales and colours like the line beside it.
  TextPainter _icon(IconData icon, double size, Color color) {
    return TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: size,
          color: color.withValues(alpha: color.a * 0.85),
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
  }

  /// Heading (with logo) and the user's extra line.
  List<_Line> _header() {
    final logo = config.showLogo && logoImage != null;
    return [
      if (content.brand != null || logo)
        _Line(content.brand ?? '', _Role.brand, withLogo: logo),
      if (content.customText != null) _Line(content.customText!, _Role.custom),
    ];
  }

  _Role get _accuracyRole => content.accuracyLevel == GpsAccuracyLevel.poor
      ? _Role.poor
      : _Role.secondary;

  static String _levelLabel(GpsAccuracyLevel? level) => switch (level) {
    GpsAccuracyLevel.good => 'Good'.tr,
    GpsAccuracyLevel.moderate => 'Moderate'.tr,
    GpsAccuracyLevel.poor || null => 'Poor'.tr,
  };

  TextStyle _style(_Role role) {
    final minimal = _template == WatermarkTemplate.minimal;
    final (size, weight, color) = switch ((_template, role)) {
      (_, _Role.brand) => (15.0, FontWeight.w700, AppColors.accent),
      (_, _Role.custom) => (20.0, FontWeight.w600, AppColors.onViewfinder),
      (_, _Role.note) => (
        minimal ? 18.0 : 20.0,
        FontWeight.w500,
        AppColors.onViewfinder,
      ),
      (WatermarkTemplate.professional, _Role.primary) => (
        27.0,
        FontWeight.w600,
        AppColors.onViewfinder,
      ),
      (final t, _Role.primary) when t.isCard => (
        27.0,
        FontWeight.w700,
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

  /// The largest rect with [image]'s shape centred in [box], so logos are
  /// never stretched.
  static Rect _fitInside(ui.Image image, Rect box) {
    final scale = math.min(box.width / image.width, box.height / image.height);
    final w = image.width * scale;
    final h = image.height * scale;
    return Rect.fromLTWH(
      box.left + (box.width - w) / 2,
      box.top + (box.height - h) / 2,
      w,
      h,
    );
  }

  /// Centre square of an image, so maps fill the square without stretching.
  static Rect _coverSquare(double width, double height) {
    final side = math.min(width, height);
    return Rect.fromLTWH((width - side) / 2, (height - side) / 2, side, side);
  }

  /// Drops letter spacing for non-Latin text, which it would break apart.
  static TextStyle _spaced(TextStyle style, String text) =>
      isLatinText(text) ? style : style.copyWith(letterSpacing: 0);

  TextStyle _labelStyle() => TextStyle(
    fontSize: 15 * _unit,
    fontWeight: FontWeight.w700,
    color: AppColors.onViewfinderMuted,
    letterSpacing: 1.4 * _unit,
    height: 1.25,
  );

  TextPainter _text(String text, TextStyle style, double maxWidth) {
    return TextPainter(
      text: TextSpan(
        text: keepLtrRuns(text, rtl: rtl),
        style: style,
      ),
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
  }
}
