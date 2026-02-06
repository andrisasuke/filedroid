import 'package:flutter_test/flutter_test.dart';
import 'package:filedroid/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const FileDroidApp());
    await tester.pump();
  });
}
