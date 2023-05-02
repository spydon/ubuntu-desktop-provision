import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:subiquity_test/subiquity_test.dart';
import 'package:ubuntu_desktop_installer/pages/welcome/rst/rst_model.dart';

void main() async {
  test('reboot', () async {
    final client = MockSubiquityClient();
    final model = RstModel(client);

    await model.reboot();
    verify(client.reboot(immediate: true)).called(1);
  });
}
