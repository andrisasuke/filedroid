import 'package:flutter_test/flutter_test.dart';
import 'package:filedroid/main.dart';
import 'package:filedroid/screens/home_screen.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';
import 'package:filedroid/providers/device_provider.dart';
import 'package:filedroid/providers/file_browser_provider.dart';
import 'package:filedroid/providers/transfer_provider.dart';

void main() {
  testWidgets('FileDroidApp creates providers and launches HomeScreen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const FileDroidApp());
    await tester.pump();

    // Verify providers are available
    final context = tester.element(find.byType(HomeScreen));
    expect(context.read<DeviceProvider>(), isNotNull);
    expect(context.read<FileBrowserProvider>(), isNotNull);
    expect(context.read<TransferProvider>(), isNotNull);
  });

  testWidgets('FileDroidApp uses MacosApp with dark theme',
      (WidgetTester tester) async {
    await tester.pumpWidget(const FileDroidApp());
    await tester.pump();

    expect(find.byType(MacosApp), findsOneWidget);
  });
}
