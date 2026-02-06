import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';

class FileDroidTheme {
  // Primary accents
  static const accentIndigo = Color(0xFF6366F1);
  static const accentCyan = Color(0xFF06B6D4);
  static const accentTeal = Color(0xFF14B8A6);

  // Status colors
  static const greenSuccess = Color(0xFF34D399);
  static const amberWarning = Color(0xFFF59E0B);
  static const roseError = Color(0xFFF43F5E);
  static const purple = Color(0xFFA855F7);

  // Backgrounds
  static const bgPrimary = Color(0xFF0C0E16);
  static const bgSurface = Color(0xFF0F111A);
  static const bgElevated = Color(0xFF1A1C2A);

  // Text
  const FileDroidTheme._();
  static const textPrimary = Color(0xFFE2E8F0);
  static const textSecondary = Color.fromRGBO(255, 255, 255, 0.5);
  static const textTertiary = Color.fromRGBO(255, 255, 255, 0.3);

  // Borders
  static const borderSubtle = Color.fromRGBO(255, 255, 255, 0.06);
  static const borderLight = Color.fromRGBO(255, 255, 255, 0.1);

  // Badge colors for file types
  static Color badgeColorForExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'bmp':
      case 'svg':
      case 'heic':
      case 'heif':
        return purple;
      case 'mp4':
      case 'mkv':
      case 'avi':
      case 'mov':
      case 'wmv':
      case 'flv':
      case 'webm':
        return roseError;
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'aac':
      case 'ogg':
      case 'm4a':
      case 'm3u':
        return amberWarning;
      case 'pdf':
        return roseError;
      case 'doc':
      case 'docx':
        return accentCyan;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return greenSuccess;
      case 'ppt':
      case 'pptx':
        return amberWarning;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return accentTeal;
      case 'apk':
        return greenSuccess;
      case 'txt':
      case 'log':
      case 'md':
      case 'json':
      case 'xml':
      case 'html':
      case 'css':
      case 'js':
        return accentCyan;
      default:
        return accentTeal;
    }
  }

  // Badge text for file extensions (2-letter code)
  static String badgeTextForExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'bmp':
      case 'svg':
      case 'heic':
      case 'heif':
        return 'IM';
      case 'mp4':
      case 'mkv':
      case 'avi':
      case 'mov':
      case 'wmv':
      case 'flv':
      case 'webm':
        return 'VD';
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'aac':
      case 'ogg':
      case 'm4a':
      case 'm3u':
        return 'AU';
      case 'pdf':
        return 'PD';
      case 'doc':
      case 'docx':
        return 'DO';
      case 'xls':
      case 'xlsx':
      case 'csv':
        return 'XL';
      case 'ppt':
      case 'pptx':
        return 'PT';
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return 'ZP';
      case 'apk':
        return 'AP';
      case 'txt':
      case 'log':
      case 'md':
        return 'TX';
      case 'json':
      case 'xml':
      case 'html':
      case 'css':
      case 'js':
        return 'TX';
      default:
        return ext.length >= 2
            ? ext.substring(0, 2).toUpperCase()
            : ext.toUpperCase();
    }
  }

  static const dirBadgeColor = accentIndigo;

  static const Map<String, Color> quickAccessColors = {
    'Internal Storage': accentIndigo,
    'Downloads': greenSuccess,
    'Camera': roseError,
    'Pictures': purple,
    'Documents': greenSuccess,
    'Music': amberWarning,
    'Movies': greenSuccess,
  };

  static BoxDecoration glassDecoration({
    Color? color,
    double borderRadius = 12,
    bool showBorder = true,
  }) {
    return BoxDecoration(
      color: (color ?? bgElevated).withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(borderRadius),
      border:
          showBorder ? Border.all(color: borderSubtle, width: 1) : null,
    );
  }

  static const storageGradient = LinearGradient(
    colors: [accentIndigo, accentCyan, greenSuccess],
  );

  static const progressGradient = LinearGradient(
    colors: [accentIndigo, accentCyan],
  );

  static const uploadGradient = LinearGradient(
    colors: [accentIndigo, Color(0xFF818CF8)],
  );

  static const downloadGradient = LinearGradient(
    colors: [accentCyan, accentTeal],
  );

  static BoxDecoration selectionDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          accentIndigo.withValues(alpha: 0.12),
          accentCyan.withValues(alpha: 0.08),
        ],
      ),
      border: const Border(
        left: BorderSide(color: accentIndigo, width: 2.5),
      ),
    );
  }

  static BoxDecoration deviceCardDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          accentIndigo.withValues(alpha: 0.12),
          accentCyan.withValues(alpha: 0.08),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
          color: accentIndigo.withValues(alpha: 0.15), width: 1),
    );
  }

  static TextStyle sectionLabelStyle() {
    return const TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
      color: textTertiary,
    );
  }

  static MacosThemeData macosTheme() {
    return MacosThemeData.dark().copyWith(
      primaryColor: accentIndigo,
      canvasColor: bgPrimary,
      brightness: Brightness.dark,
    );
  }
}
