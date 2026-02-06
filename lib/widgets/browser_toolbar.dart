import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/file_browser_provider.dart';
import '../providers/transfer_provider.dart';
import '../utils/theme.dart';

class BrowserToolbar extends StatelessWidget {
  const BrowserToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    final browser = context.watch<FileBrowserProvider>();
    final transfer = context.read<TransferProvider>();

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: FileDroidTheme.bgSurface.withValues(alpha: 0.8),
        border: const Border(
          bottom: BorderSide(color: FileDroidTheme.borderSubtle),
        ),
      ),
      child: Flex(
        direction: Axis.horizontal,
        clipBehavior: Clip.hardEdge,
        children: [
          // Navigation buttons
          _NavButton(
            icon: Icons.chevron_left,
            tooltip: 'Go Back',
            enabled: browser.canGoBack,
            onTap: browser.goBack,
          ),
          const SizedBox(width: 4),
          _NavButton(
            icon: Icons.chevron_right,
            tooltip: 'Go Forward',
            enabled: browser.canGoForward,
            onTap: browser.goForward,
          ),
          const SizedBox(width: 4),
          _NavButton(
            icon: Icons.arrow_upward,
            tooltip: 'Go Up',
            enabled: !browser.isAtRoot,
            onTap: browser.navigateUp,
          ),
          const SizedBox(width: 8),
          // Breadcrumb
          Expanded(
            child: _Breadcrumb(
              segments: browser.breadcrumbs,
              onTap: (index) {
                final path = browser.pathForBreadcrumb(index);
                browser.navigateTo(path);
              },
            ),
          ),
          const SizedBox(width: 8),
          // Refresh button
          _ToolButton(
            label: 'R',
            tooltip: 'Refresh',
            onTap: () => browser.refresh(),
          ),
          const SizedBox(width: 4),
          // Toggle hidden
          _ToolButton(
            label: 'E',
            tooltip: browser.showHidden ? 'Hide Hidden Files' : 'Show Hidden Files',
            isActive: browser.showHidden,
            onTap: () => browser.toggleHidden(),
          ),
          const SizedBox(width: 8),
          // Upload button
          _GradientButton(
            label: '\u2303 Upload',
            tooltip: 'Upload files to device',
            gradient: FileDroidTheme.uploadGradient,
            onTap: () => _handleUpload(context, browser, transfer),
          ),
          const SizedBox(width: 6),
          // Download button
          _GradientButton(
            label: browser.hasSelection
                ? '\u2304 Download (${browser.selectionCount})'
                : '\u2304 Download',
            tooltip: browser.hasSelection
                ? 'Download ${browser.selectionCount} selected files'
                : 'Select files to download',
            gradient: browser.hasSelection
                ? FileDroidTheme.downloadGradient
                : null,
            enabled: browser.hasSelection,
            onTap: browser.hasSelection
                ? () => _handleDownload(context, browser, transfer)
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _handleUpload(BuildContext context,
      FileBrowserProvider browser, TransferProvider transfer) async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || result.files.isEmpty) return;

    final paths = result.files
        .where((f) => f.path != null)
        .map((f) => f.path!)
        .toList();
    if (paths.isNotEmpty) {
      transfer.pushFiles(paths, browser.currentPath);
    }
  }

  Future<void> _handleDownload(BuildContext context,
      FileBrowserProvider browser, TransferProvider transfer) async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null) return;

    final remotePaths = browser.selectedFiles.map((f) => f.path).toList();
    if (remotePaths.isNotEmpty) {
      transfer.pullFiles(remotePaths, dir);
      browser.deselectAll();
    }
  }
}

class _NavButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.enabled ? widget.onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _hovering && widget.enabled
                  ? FileDroidTheme.bgElevated
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.enabled
                    ? FileDroidTheme.borderLight
                    : FileDroidTheme.borderSubtle,
              ),
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color: widget.enabled
                  ? FileDroidTheme.textPrimary
                  : FileDroidTheme.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatefulWidget {
  final String label;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

  const _ToolButton({
    required this.label,
    required this.tooltip,
    this.isActive = false,
    required this.onTap,
  });

  @override
  State<_ToolButton> createState() => _ToolButtonState();
}

class _ToolButtonState extends State<_ToolButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: widget.isActive
                  ? FileDroidTheme.accentIndigo.withValues(alpha: 0.15)
                  : _hovering
                      ? FileDroidTheme.bgElevated
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: FileDroidTheme.borderLight),
            ),
            child: Center(
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: widget.isActive
                      ? FileDroidTheme.accentCyan
                      : FileDroidTheme.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientButton extends StatefulWidget {
  final String label;
  final String tooltip;
  final LinearGradient? gradient;
  final bool enabled;
  final VoidCallback? onTap;

  const _GradientButton({
    required this.label,
    required this.tooltip,
    this.gradient,
    this.enabled = true,
    this.onTap,
  });

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.enabled ? widget.onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              gradient: widget.gradient,
              color: widget.gradient == null
                  ? (_hovering
                      ? FileDroidTheme.bgElevated.withValues(alpha: 0.9)
                      : FileDroidTheme.bgElevated)
                  : null,
              borderRadius: BorderRadius.circular(8),
              border: widget.gradient == null
                  ? Border.all(color: FileDroidTheme.borderLight)
                  : null,
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: widget.enabled
                    ? Colors.white
                    : FileDroidTheme.textTertiary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  final List<String> segments;
  final void Function(int index) onTap;

  const _Breadcrumb({required this.segments, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: FileDroidTheme.bgElevated.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FileDroidTheme.borderSubtle),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < segments.length; i++) ...[
              if (i > 0)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '>',
                    style: TextStyle(
                      fontSize: 12,
                      color: FileDroidTheme.textTertiary,
                    ),
                  ),
                ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => onTap(i),
                  child: Text(
                    segments[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Menlo',
                      fontWeight: FontWeight.w500,
                      color: i == segments.length - 1
                          ? FileDroidTheme.accentCyan
                          : FileDroidTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
