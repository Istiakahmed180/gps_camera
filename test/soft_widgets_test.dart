import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_camera/app/theme/app_theme.dart';
import 'package:gps_camera/shared/widgets/app_button.dart';
import 'package:gps_camera/shared/widgets/soft_surface.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(child: SizedBox(width: 360, child: child)),
      ),
    ),
  );

  testWidgets('a full-width primary button centres its label', (tester) async {
    var taps = 0;
    await pump(
      tester,
      AppButton(label: 'Save', isExpanded: true, onPressed: () => taps++),
    );
    final button = tester.getRect(find.byType(GlossyButton));
    final label = tester.getRect(find.text('Save'));
    expect(button.width, 360);
    expect(label.center.dx, closeTo(button.center.dx, 1));

    await tester.tap(find.text('Save'));
    expect(taps, 1);
  });

  testWidgets('a disabled glossy button ignores taps', (tester) async {
    await pump(tester, const GlossyButton(label: 'Next', onPressed: null));
    await tester.tap(find.text('Next'));
    final opacity = tester.widget<AnimatedOpacity>(
      find.byType(AnimatedOpacity),
    );
    expect(opacity.opacity, lessThan(1));
  });
}
