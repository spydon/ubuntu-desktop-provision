import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubuntu_provision/src/keyboard/keyboard_l10n.dart';
import 'package:ubuntu_provision/src/keyboard/keyboard_widgets.dart';

import '../test_utils.dart';

void main() {
  testWidgets('press key', (tester) async {
    int? keyPress;

    await tester.pumpWidget(
      tester.buildApp(
        (_) => DetectKeyboardView(
          pressKey: const ['x', 'y', 'z'],
          onKeyPress: (code) => keyPress = code,
        ),
      ),
    );

    final context = tester.element(find.byType(DetectKeyboardView));
    final l10n = KeyboardLocalizations.of(context);

    expect(find.byType(PressKeyView), findsOneWidget);
    expect(find.text('x'), findsOneWidget);
    expect(find.text('y'), findsOneWidget);
    expect(find.text('z'), findsOneWidget);
    expect(find.text(l10n.keyboardPressKeyLabel), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyW, platform: 'linux');
    expect(keyPress, equals(25 - 8));

    await tester.sendKeyEvent(LogicalKeyboardKey.keyX, platform: 'linux');
    expect(keyPress, equals(53 - 8));
  });

  testWidgets('find key', (tester) async {
    await tester.pumpWidget(
      tester.buildApp((_) => const DetectKeyboardView(keyPresent: 'x')),
    );

    final context = tester.element(find.byType(DetectKeyboardView));
    final l10n = KeyboardLocalizations.of(context);

    expect(find.byType(KeyPresentView), findsOneWidget);
    expect(find.text('x'), findsOneWidget);
    expect(find.text(l10n.keyboardKeyPresentLabel), findsOneWidget);
  });
}
