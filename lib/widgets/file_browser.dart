import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../models/android_file.dart';
import '../providers/device_provider.dart';
import '../providers/file_browser_provider.dart';
import '../providers/transfer_provider.dart';
import '../utils/theme.dart';

class FileBrowser extends StatefulWidget {
  const FileBrowser({super.key});

  @override
  State<FileBrowser> createState() => _FileBrowserState();
}

class _FileBrowserState extends State<FileBrowser> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final deviceProv = context.watch<DeviceProvider>();
    final browser = context.watch<FileBrowserProvider>();
    final transfer = context.read<TransferProvider>();

    // No device state
    if (!deviceProv.hasDevice) {
      if (deviceProv.activeDevice?.isUnauthorized == true) {
        return _buildUnauthorizedState();
      }
      return _buildNoDeviceState();
    }

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) {
        setState(() => _isDragging = false);
        final paths = details.files.map((f) => f.path).toList();
        if (paths.isNotEmpty) {
          transfer.pushFiles(paths, browser.currentPath);
        }
      },
      child: Stack(
        children: [
          Column(
            children: [
              // Column headers
              _buildColumnHeaders(browser),
              // File list
              Expanded(child: _buildFileList(browser)),
              // Status bar
              _buildStatusBar(browser),
            ],
          ),
          // Drop overlay
          if (_isDragging) _buildDropOverlay(browser),
        ],
      ),
    );
  }

  Widget _buildColumnHeaders(FileBrowserProvider browser) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: FileBeamTheme.borderSubtle),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 38), // checkbox + badge space
          Expanded(
            flex: 5,
            child: _SortHeader(
              label: 'Name',
              isActive: browser.sortMode == SortMode.name,
              ascending: browser.sortAscending,
              onTap: () => browser.setSortMode(SortMode.name),
            ),
          ),
          SizedBox(
            width: 90,
            child: _SortHeader(
              label: 'Size',
              isActive: browser.sortMode == SortMode.size,
              ascending: browser.sortAscending,
              onTap: () => browser.setSortMode(SortMode.size),
              align: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 120,
            child: _SortHeader(
              label: 'Modified',
              isActive: browser.sortMode == SortMode.date,
              ascending: browser.sortAscending,
              onTap: () => browser.setSortMode(SortMode.date),
              align: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileList(FileBrowserProvider browser) {
    if (browser.isLoading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: FileBeamTheme.accentIndigo,
          ),
        ),
      );
    }

    if (browser.error != null) {
      return Center(
        child: Text(
          browser.error!,
          style: const TextStyle(color: FileBeamTheme.roseError, fontSize: 14),
        ),
      );
    }

    if (browser.files.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      itemCount: browser.files.length,
      itemBuilder: (context, index) {
        final file = browser.files[index];
        return _FileRow(
          file: file,
          isSelected: browser.selectedPaths.contains(file.path),
          animationDelay: index,
          onTap: () {
            if (file.isDirectory) {
              browser.navigateTo(file.path);
            } else {
              browser.toggleSelection(file);
            }
          },
          onSelect: () => browser.toggleSelection(file),
        );
      },
    );
  }

  Widget _buildStatusBar(FileBrowserProvider browser) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: FileBeamTheme.bgSurface,
        border: Border(
          top: BorderSide(color: FileBeamTheme.borderSubtle),
        ),
      ),
      child: Row(
        children: [
          Text(
            '${browser.files.length} items',
            style: const TextStyle(
              fontSize: 11,
              color: FileBeamTheme.textTertiary,
            ),
          ),
          const Spacer(),
          if (browser.hasSelection)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: FileBeamTheme.accentIndigo.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${browser.selectionCount} selected',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: FileBeamTheme.accentCyan,
                ),
              ),
            ),
          const Spacer(),
          Text(
            browser.currentPath.replaceFirst('/sdcard', '/sdcard'),
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'Menlo',
              color: FileBeamTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDeviceState() {
    return Container(
      color: FileBeamTheme.bgPrimary,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: FileBeamTheme.bgElevated,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text(
                  '[ ]',
                  style: TextStyle(
                    fontSize: 24,
                    color: FileBeamTheme.textTertiary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Connect Your Android Device',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: FileBeamTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '1. Enable USB Debugging on your phone',
              style: TextStyle(
                  fontSize: 14, color: FileBeamTheme.textSecondary),
            ),
            const SizedBox(height: 6),
            const Text(
              '2. Connect via USB cable',
              style: TextStyle(
                  fontSize: 14, color: FileBeamTheme.textSecondary),
            ),
            const SizedBox(height: 6),
            const Text(
              '3. Accept the connection prompt',
              style: TextStyle(
                  fontSize: 14, color: FileBeamTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnauthorizedState() {
    return Container(
      color: FileBeamTheme.bgPrimary,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: FileBeamTheme.amberWarning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: FileBeamTheme.amberWarning.withValues(alpha: 0.3),
                ),
              ),
              child: const Center(
                child: Text(
                  '!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: FileBeamTheme.amberWarning,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Authorization Required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: FileBeamTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your device needs to authorize this computer.\n'
              'Check your phone for the USB debugging prompt\n'
              'and tap "Allow" to continue.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: FileBeamTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FileBeamTheme.amberWarning.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: FileBeamTheme.amberWarning.withValues(alpha: 0.15),
                ),
              ),
              child: const Text(
                'Tip: Check "Always allow from this\ncomputer" to skip this next time.',
                style: TextStyle(
                  fontSize: 13,
                  color: FileBeamTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: FileBeamTheme.bgElevated,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text(
                '[ ]',
                style: TextStyle(
                  fontSize: 20,
                  color: FileBeamTheme.textTertiary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'This folder is empty',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: FileBeamTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Drag files here to upload',
            style: TextStyle(
              fontSize: 13,
              color: FileBeamTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropOverlay(FileBrowserProvider browser) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        child: Center(
          child: Container(
            width: 300,
            height: 180,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  FileBeamTheme.accentIndigo,
                  FileBeamTheme.accentCyan,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: FileBeamTheme.accentIndigo.withValues(alpha: 0.4),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'DL',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Drop files to upload',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Files will be copied to ${browser.currentPath}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SortHeader extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool ascending;
  final VoidCallback onTap;
  final TextAlign align;

  const _SortHeader({
    required this.label,
    required this.isActive,
    required this.ascending,
    required this.onTap,
    this.align = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisAlignment: align == TextAlign.right
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive
                    ? FileBeamTheme.textPrimary
                    : FileBeamTheme.textTertiary,
              ),
            ),
            if (isActive)
              Icon(
                ascending
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
                size: 12,
                color: FileBeamTheme.textPrimary,
              ),
          ],
        ),
      ),
    );
  }
}

class _FileRow extends StatefulWidget {
  final AndroidFile file;
  final bool isSelected;
  final int animationDelay;
  final VoidCallback onTap;
  final VoidCallback onSelect;

  const _FileRow({
    required this.file,
    required this.isSelected,
    required this.animationDelay,
    required this.onTap,
    required this.onSelect,
  });

  @override
  State<_FileRow> createState() => _FileRowState();
}

class _FileRowState extends State<_FileRow>
    with SingleTickerProviderStateMixin {
  bool _hovering = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _animController, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: widget.animationDelay * 30), () {
      if (mounted) _animController.forward();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: widget.isSelected
                  ? FileBeamTheme.selectionDecoration()
                  : BoxDecoration(
                      color: _hovering
                          ? FileBeamTheme.bgElevated.withValues(alpha: 0.4)
                          : Colors.transparent,
                    ),
              child: Row(
                children: [
                  // Checkbox area
                  SizedBox(
                    width: 24,
                    child: (_hovering || widget.isSelected) &&
                            !widget.file.isDirectory
                        ? GestureDetector(
                            onTap: widget.onSelect,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: widget.isSelected
                                    ? FileBeamTheme.accentIndigo
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: widget.isSelected
                                      ? FileBeamTheme.accentIndigo
                                      : FileBeamTheme.textTertiary,
                                  width: 1.5,
                                ),
                              ),
                              child: widget.isSelected
                                  ? const Icon(Icons.check,
                                      size: 13, color: Colors.white)
                                  : null,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 4),
                  // Badge
                  Container(
                    width: 26,
                    height: 20,
                    decoration: BoxDecoration(
                      color: widget.file.badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        widget.file.badgeText,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: widget.file.badgeColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Name
                  Expanded(
                    flex: 5,
                    child: Text.rich(
                      TextSpan(
                        text: widget.file.name,
                        children: [
                          if (widget.file.isDirectory)
                            TextSpan(
                              text: ' >',
                              style: TextStyle(
                                color: FileBeamTheme.textTertiary,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: widget.file.isDirectory
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: FileBeamTheme.textPrimary,
                      ),
                    ),
                  ),
                  // Size
                  SizedBox(
                    width: 90,
                    child: Text(
                      widget.file.formattedSize,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        color: FileBeamTheme.textSecondary,
                        fontFamily: 'Menlo',
                      ),
                    ),
                  ),
                  // Date
                  SizedBox(
                    width: 120,
                    child: Text(
                      widget.file.formattedDate,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        color: FileBeamTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
