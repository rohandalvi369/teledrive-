import 'package:flutter_test/flutter_test.dart';
import 'package:teledrive/main.dart';

void main() {
  testWidgets('App smoke test', (tester) async {
    await tester.pumpWidget(const TeleDriveApp());
    expect(find.text('TeleDrive'), findsWidgets);
  });
}
