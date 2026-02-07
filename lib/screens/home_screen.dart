import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';
import '../providers/file_browser_provider.dart';
import '../providers/transfer_provider.dart';
import '../utils/theme.dart';
import '../widgets/adb_setup_screen.dart';
import '../widgets/browser_toolbar.dart';
import '../widgets/device_panel.dart';
import '../widgets/file_browser.dart';
import '../widgets/transfer_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showTransfers = true;
  bool _hasLoadedBrowser = false;
  DeviceProvider? _deviceProv;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _deviceProv = context.read<DeviceProvider>();
      _deviceProv!.initialize();
      _deviceProv!.addListener(_onDeviceChanged);
      context.read<TransferProvider>().onTransferComplete = () {
        context.read<FileBrowserProvider>().refresh();
      };
    });
  }

  void _onDeviceChanged() {
    if (_hasLoadedBrowser) return;
    if (_deviceProv?.hasDevice == true) {
      _hasLoadedBrowser = true;
      context.read<FileBrowserProvider>().navigateTo('/sdcard');
    }
  }

  @override
  void dispose() {
    _deviceProv?.removeListener(_onDeviceChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deviceProv = context.watch<DeviceProvider>();

    return MacosWindow(
      titleBar: TitleBar(
        height: 48,
        centerTitle: false,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: FileDroidTheme.bgSurface.withValues(alpha: 0.9),
        ),
        title: Row(
          children: [
            // FileDroid logo in title bar, aligned left with sidebar
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: FileDroidTheme.uploadGradient,
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Center(
                child: Icon(Icons.android, color: Colors.white, size: 17),
              ),
            ),
            const SizedBox(width: 8),
            const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FileDroid',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: FileDroidTheme.textPrimary,
                  ),
                ),
                Text(
                  'Android Transfer',
                  style: TextStyle(
                    fontSize: 10,
                    color: FileDroidTheme.textTertiary,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Transfer panel toggle button
            Tooltip(
              message: _showTransfers ? 'Hide Transfers' : 'Show Transfers',
              waitDuration: const Duration(milliseconds: 500),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _showTransfers = !_showTransfers),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _showTransfers
                          ? FileDroidTheme.accentIndigo
                              .withValues(alpha: 0.15)
                          : FileDroidTheme.bgElevated,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: FileDroidTheme.borderLight),
                    ),
                    child: Center(
                      child: Text(
                        'T',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _showTransfers
                              ? FileDroidTheme.accentCyan
                              : FileDroidTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      child: _buildBody(deviceProv),
    );
  }

  Widget _buildBody(DeviceProvider deviceProv) {
    if (deviceProv.isLoading) {
      return Container(
        color: FileDroidTheme.bgPrimary,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: FileDroidTheme.accentIndigo,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Initializing...',
                style: TextStyle(
                  fontSize: 14,
                  color: FileDroidTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!deviceProv.adbAvailable) {
      return AdbSetupScreen(onRetry: () => deviceProv.retryInitialize());
    }

    return Stack(
      children: [
        // Background
        Container(color: FileDroidTheme.bgPrimary),
        // Ambient glow orbs
        ..._buildGlowOrbs(),
        // Main layout
        Row(
          children: [
            // Sidebar
            const DevicePanel(),
            // Divider
            Container(width: 1, color: FileDroidTheme.borderSubtle),
            // Content area
            Expanded(
              child: Column(
                children: [
                  const BrowserToolbar(),
                  const Expanded(child: FileBrowser()),
                ],
              ),
            ),
            // Transfer panel
            if (_showTransfers) const TransferPanel(),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildGlowOrbs() {
    return [
      Positioned(
        top: -100,
        left: -80,
        child: _GlowOrb(color: FileDroidTheme.accentIndigo, size: 350),
      ),
      Positioned(
        bottom: -120,
        right: -60,
        child: _GlowOrb(color: FileDroidTheme.accentCyan, size: 300),
      ),
      Positioned(
        bottom: -80,
        left: -40,
        child: _GlowOrb(color: FileDroidTheme.roseError, size: 250),
      ),
      Positioned(
        top: -60,
        right: -100,
        child: _GlowOrb(color: FileDroidTheme.purple, size: 280),
      ),
    ];
  }
}

class _GlowOrb extends StatefulWidget {
  final Color color;
  final double size;

  const _GlowOrb({required this.color, required this.size});

  @override
  State<_GlowOrb> createState() => _GlowOrbState();
}

class _GlowOrbState extends State<_GlowOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            10 * (_controller.value - 0.5),
            8 * (_controller.value - 0.5),
          ),
          child: child,
        );
      },
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: 0.18),
          ),
        ),
      ),
    );
  }
}
