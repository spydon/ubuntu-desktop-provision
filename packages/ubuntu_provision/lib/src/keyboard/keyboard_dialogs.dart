import 'package:flutter/material.dart';
import 'package:ubuntu_localizations/ubuntu_localizations.dart';
import 'package:ubuntu_provision/services.dart';
import 'package:ubuntu_service/ubuntu_service.dart';
import 'package:ubuntu_widgets/ubuntu_widgets.dart';
import 'package:ubuntu_wizard/ubuntu_wizard.dart';
import 'package:yaru_widgets/yaru_widgets.dart';

import 'keyboard_detector.dart';
import 'keyboard_l10n.dart';
import 'keyboard_widgets.dart';

const _kDialogWidthFactor = 0.65;
const _kDialogHeightFactor = 0.15;

/// Shows a dialog to detect the keyboard layout by asking the user to press
/// and confirm keys. Returns the result with a keyboard layout and variant
/// codes or null if canceled.
Future<StepResult?> showDetectKeyboardDialog(BuildContext context) async {
  final service = getService<KeyboardService>();

  return showDialog<StepResult?>(
    context: context,
    builder: (context) {
      final detector = KeyboardDetector(service, onResult: (result) {
        Navigator.of(context).pop(result);
      });
      detector.init();

      final lang = KeyboardLocalizations.of(context);
      return ValueListenableBuilder<AnyStep?>(
        valueListenable: detector,
        builder: (context, step, _) {
          final size = MediaQuery.of(context).size;
          return AlertDialog(
            title: YaruDialogTitleBar(
              title: Text(lang.keyboardDetectTitle),
            ),
            titlePadding: EdgeInsets.zero,
            contentPadding: const EdgeInsets.all(kYaruPagePadding),
            actionsPadding: const EdgeInsets.all(kYaruPagePadding),
            buttonPadding: EdgeInsets.zero,
            content: SizedBox(
              width: size.width * _kDialogWidthFactor,
              height: size.height * _kDialogHeightFactor,
              child: DetectKeyboardView(
                pressKey: detector.pressKey,
                keyPresent: detector.keyPresent,
                onKeyPress: detector.press,
              ),
            ),
            actions: <Widget>[
              Visibility(
                maintainSize: true,
                maintainState: true,
                maintainAnimation: true,
                visible: step is StepKeyPresent,
                child: PushButton.filled(
                  onPressed: step is StepKeyPresent ? detector.no : null,
                  child: Text(UbuntuLocalizations.of(context).noLabel),
                ),
              ),
              const SizedBox(width: kWizardBarSpacing),
              Visibility(
                maintainSize: true,
                maintainState: true,
                maintainAnimation: true,
                visible: step is StepKeyPresent,
                child: PushButton.filled(
                  onPressed: step is StepKeyPresent ? detector.yes : null,
                  child: Text(UbuntuLocalizations.of(context).yesLabel),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
