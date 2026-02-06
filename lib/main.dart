import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';
import 'providers/device_provider.dart';
import 'providers/file_browser_provider.dart';
import 'providers/transfer_provider.dart';
import 'screens/home_screen.dart';
import 'services/adb_service.dart';
import 'utils/theme.dart';

void main() {
  runApp(const FileDroidApp());
}

class FileDroidApp extends StatelessWidget {
  const FileDroidApp({super.key});

  @override
  Widget build(BuildContext context) {
    final adbService = AdbService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DeviceProvider(adbService)),
        ChangeNotifierProvider(
            create: (_) => FileBrowserProvider(adbService)),
        ChangeNotifierProvider(
            create: (_) => TransferProvider(adbService)),
      ],
      child: MacosApp(
        title: 'FileDroid',
        theme: FileDroidTheme.macosTheme(),
        darkTheme: FileDroidTheme.macosTheme(),
        themeMode: ThemeMode.dark,
        debugShowCheckedModeBanner: false,
        home: const HomeScreen(),
      ),
    );
  }
}
