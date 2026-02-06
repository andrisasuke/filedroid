import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/device_provider.dart';
import '../utils/theme.dart';

class AdbSetupScreen extends StatefulWidget {
  final VoidCallback onRetry;

  const AdbSetupScreen({super.key, required this.onRetry});

  @override
  State<AdbSetupScreen> createState() => _AdbSetupScreenState();
}

class _AdbSetupScreenState extends State<AdbSetupScreen> {
  String? _browseError;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: FileBeamTheme.bgPrimary,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Warning icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: FileBeamTheme.bgElevated,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text(
                  '!!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: FileBeamTheme.amberWarning,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'ADB Not Found',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: FileBeamTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Android Debug Bridge is required to communicate\nwith your device. Install it using one of these methods:',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: FileBeamTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            // Homebrew option
            _OptionCard(
              title: 'Homebrew (Recommended)',
              subtitle: 'brew install android-platform-tools',
              isCode: true,
              onTap: () {},
            ),
            const SizedBox(height: 12),
            // Manual download option
            _OptionCard(
              title: 'Android SDK Platform Tools',
              subtitle: 'developer.android.com/tools',
              isCode: false,
              onTap: () {
                launchUrl(Uri.parse(
                    'https://developer.android.com/tools/releases/platform-tools'));
              },
            ),
            const SizedBox(height: 16),
            // Browse option
            _OptionCard(
              title: 'Browse for ADB',
              subtitle: 'Locate adb binary manually',
              isCode: false,
              onTap: () => _handleBrowse(context),
            ),
            if (_browseError != null) ...[
              const SizedBox(height: 10),
              Text(
                _browseError!,
                style: const TextStyle(
                  fontSize: 13,
                  color: FileBeamTheme.roseError,
                ),
              ),
            ],
            const SizedBox(height: 28),
            // Retry button
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onRetry,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: FileBeamTheme.downloadGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleBrowse(BuildContext context) async {
    final deviceProv = context.read<DeviceProvider>();
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select adb binary',
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;
    if (!mounted) return;

    final path = result.files.first.path!;
    final ok = await deviceProv.setCustomAdbPath(path);
    if (!mounted) return;
    if (!ok) {
      setState(() => _browseError = 'Selected file is not a valid adb binary');
    } else {
      setState(() => _browseError = null);
    }
  }
}

class _OptionCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool isCode;
  final VoidCallback onTap;

  const _OptionCard({
    required this.title,
    required this.subtitle,
    required this.isCode,
    required this.onTap,
  });

  @override
  State<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<_OptionCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 400,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _hovering
                ? FileBeamTheme.bgElevated
                : FileBeamTheme.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovering
                  ? FileBeamTheme.accentIndigo.withValues(alpha: 0.3)
                  : FileBeamTheme.borderSubtle,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: FileBeamTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.subtitle,
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: widget.isCode ? 'Menlo' : null,
                  color: widget.isCode
                      ? FileBeamTheme.accentCyan
                      : FileBeamTheme.accentCyan,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
