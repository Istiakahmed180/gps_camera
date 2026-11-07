import 'package:flutter/material.dart';
import 'package:gps_camera/app/theme/app_colors.dart';

/// Sits over the live preview: pinch to zoom, tap to focus, the grid and
/// the timer countdown. None of it is drawn into the photo.
class ViewfinderLayer extends StatefulWidget {
  const ViewfinderLayer({
    super.key,
    required this.zoom,
    required this.onZoom,
    required this.onFocus,
    required this.focusPoint,
    required this.focusTaps,
    required this.showGrid,
    required this.countdown,
    this.child,
  });

  final double zoom;
  final ValueChanged<double> onZoom;

  /// Called with the tap as a fraction of the preview.
  final ValueChanged<Offset> onFocus;
  final Offset? focusPoint;

  /// Changes on every focus tap, so the ring animates each time.
  final int focusTaps;
  final bool showGrid;
  final int? countdown;

  /// Drawn on top, e.g. the live watermark. Its own taps win.
  final Widget? child;

  @override
  State<ViewfinderLayer> createState() => _ViewfinderLayerState();
}

class _ViewfinderLayerState extends State<ViewfinderLayer> {
  double _baseZoom = 1;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final focus = widget.focusPoint;
        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => widget.onFocus(
                Offset(
                  d.localPosition.dx / size.width,
                  d.localPosition.dy / size.height,
                ),
              ),
              onScaleStart: (_) => _baseZoom = widget.zoom,
              onScaleUpdate: (d) {
                if (d.pointerCount >= 2) widget.onZoom(_baseZoom * d.scale);
              },
            ),
            if (widget.showGrid)
              const IgnorePointer(child: CustomPaint(painter: _GridPainter())),
            if (focus != null)
              Positioned(
                left: focus.dx * size.width - _FocusRing.size / 2,
                top: focus.dy * size.height - _FocusRing.size / 2,
                child: IgnorePointer(
                  child: _FocusRing(key: ValueKey(widget.focusTaps)),
                ),
              ),
            if (widget.child != null) widget.child!,
            if (widget.countdown != null)
              IgnorePointer(
                child: Center(
                  child: Text(
                    '${widget.countdown}',
                    key: ValueKey(widget.countdown),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 96,
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(blurRadius: 16)],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      final y = size.height * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}

/// A square that shrinks into place, then fades.
class _FocusRing extends StatefulWidget {
  const _FocusRing({super.key});

  static const double size = 72;

  @override
  State<_FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<_FocusRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final t = _anim.value;
        final scale =
            1.25 - 0.25 * Curves.easeOut.transform((t * 4).clamp(0, 1));
        final opacity = t < 0.7 ? 1.0 : 1 - (t - 0.7) / 0.3;
        return Opacity(
          opacity: opacity.clamp(0, 1),
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: _FocusRing.size,
              height: _FocusRing.size,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.accent, width: 1.5),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        );
      },
    );
  }
}
