import 'package:flutter_test/flutter_test.dart';
import 'package:filebeam/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const FileBeamApp());
    await tester.pump();
  });
}
