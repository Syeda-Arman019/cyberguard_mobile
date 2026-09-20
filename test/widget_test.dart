import 'package:flutter_test/flutter_test.dart';
import 'package:cyberguard_mobile/main.dart';
import 'package:cyberguard_mobile/screens/manual_scan_screen.dart';

void main() {
  testWidgets('CyberGuardApp smoke test renders ManualScanScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const CyberGuardApp());

    expect(find.byType(ManualScanScreen), findsOneWidget);
  });
}
