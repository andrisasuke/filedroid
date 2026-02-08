import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';
import '../providers/file_browser_provider.dart';
import '../services/adb_service.dart';
import '../utils/theme.dart';

class DevicePanel extends StatelessWidget {
  const DevicePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final deviceProv = context.watch<DeviceProvider>();
    final browserProv = context.watch<FileBrowserProvider>();

    return Container(
      width: 240,
      color: FileDroidTheme.bgSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // Device card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _buildDeviceCard(deviceProv),
          ),
          // Storage info
          if (deviceProv.storageInfo != null && deviceProv.hasDevice) ...[
            const SizedBox(height: 16),
            _buildStorageBar(deviceProv.storageInfo!),
          ],
          const SizedBox(height: 20),
          // Quick Access
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'QUICK ACCESS',
              style: FileDroidTheme.sectionLabelStyle(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _QuickAccessItem(
                  label: 'Internal Storage',
                  isActive:
                      browserProv.activeQuickAccess == 'Internal Storage',
                  onTap: () => browserProv.goToSdcard(),
                ),
                _QuickAccessItem(
                  label: 'Downloads',
                  isActive: browserProv.activeQuickAccess == 'Downloads',
                  onTap: () => browserProv.goToDownloads(),
                ),
                _QuickAccessItem(
                  label: 'Camera',
                  isActive: browserProv.activeQuickAccess == 'Camera',
                  onTap: () => browserProv.goToDCIM(),
                ),
                _QuickAccessItem(
                  label: 'Pictures',
                  isActive: browserProv.activeQuickAccess == 'Pictures',
                  onTap: () => browserProv.goToPictures(),
                ),
                _QuickAccessItem(
                  label: 'Documents',
                  isActive: browserProv.activeQuickAccess == 'Documents',
                  onTap: () => browserProv.goToDocuments(),
                ),
                _QuickAccessItem(
                  label: 'Music',
                  isActive: browserProv.activeQuickAccess == 'Music',
                  onTap: () => browserProv.goToMusic(),
                ),
                _QuickAccessItem(
                  label: 'Movies',
                  isActive: browserProv.activeQuickAccess == 'Movies',
                  onTap: () => browserProv.goToMovies(),
                ),
              ],
            ),
          ),
          // ADB version
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              deviceProv.adbVersion != null
                  ? 'adb ${deviceProv.adbVersion} \u2022 Platform Tools'
                  : '',
              style: const TextStyle(
                fontSize: 11,
                color: FileDroidTheme.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(DeviceProvider prov) {
    final device = prov.activeDevice;
    final hasDevice = device != null;

    Color dotColor;
    String title;
    String subtitle;
    String detail;

    if (!hasDevice) {
      dotColor = FileDroidTheme.textTertiary;
      title = '[phone]';
      subtitle = 'No Device Connected';
      detail = 'Connect via USB cable';
    } else if (device.isUnauthorized) {
      dotColor = FileDroidTheme.amberWarning;
      title = device.displayName;
      subtitle = 'Unauthorized';
      detail = 'Check phone for prompt';
    } else {
      dotColor = FileDroidTheme.greenSuccess;
      title = device.displayName;
      final version =
          device.androidVersion != null ? 'Android ${device.androidVersion}' : '';
      subtitle = '$version \u2022 USB 3.0'.trim();
      detail = device.id;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: hasDevice && device.isOnline
          ? FileDroidTheme.deviceCardDecoration()
          : BoxDecoration(
              color: FileDroidTheme.bgElevated.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FileDroidTheme.borderSubtle),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: hasDevice
                        ? FileDroidTheme.textPrimary
                        : FileDroidTheme.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: device?.isUnauthorized == true
                        ? FileDroidTheme.amberWarning
                        : FileDroidTheme.textSecondary,
                  ),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: const TextStyle(
                      fontSize: 10,
                      fontFamily: 'Menlo',
                      color: FileDroidTheme.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageBar(StorageInfo info) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'STORAGE',
                style: FileDroidTheme.sectionLabelStyle(),
              ),
              Flexible(
                child: Text(
                  '${info.formattedUsed} / ${info.formattedTotal}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: FileDroidTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Gradient progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: FileDroidTheme.bgElevated,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: info.usedPercentage,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: FileDroidTheme.storageGradient,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${info.formattedAvailable} available',
            style: const TextStyle(
              fontSize: 11,
              color: FileDroidTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAccessItem extends StatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _QuickAccessItem({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_QuickAccessItem> createState() => _QuickAccessItemState();
}

class _QuickAccessItemState extends State<_QuickAccessItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final dotColor =
        FileDroidTheme.quickAccessColors[widget.label] ??
            FileDroidTheme.accentTeal;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isActive
                ? FileDroidTheme.accentIndigo.withValues(alpha: 0.12)
                : _hovering
                    ? FileDroidTheme.bgElevated.withValues(alpha: 0.5)
                    : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: widget.isActive
                    ? FileDroidTheme.accentIndigo
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        widget.isActive ? FontWeight.w600 : FontWeight.w400,
                    color: widget.isActive
                        ? FileDroidTheme.textPrimary
                        : FileDroidTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
