import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:filedroid/utils/theme.dart';

void main() {
  group('FileDroidTheme', () {
    group('badgeColorForExtension', () {
      test('returns purple for image extensions', () {
        for (final ext in ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg', 'heic', 'heif']) {
          expect(FileDroidTheme.badgeColorForExtension(ext), FileDroidTheme.purple,
              reason: '$ext should be purple');
        }
      });

      test('returns roseError for video extensions', () {
        for (final ext in ['mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm']) {
          expect(FileDroidTheme.badgeColorForExtension(ext), FileDroidTheme.roseError,
              reason: '$ext should be roseError');
        }
      });

      test('returns amberWarning for audio extensions', () {
        for (final ext in ['mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a', 'm3u']) {
          expect(FileDroidTheme.badgeColorForExtension(ext), FileDroidTheme.amberWarning,
              reason: '$ext should be amberWarning');
        }
      });

      test('returns roseError for pdf', () {
        expect(FileDroidTheme.badgeColorForExtension('pdf'), FileDroidTheme.roseError);
      });

      test('returns accentCyan for doc/docx', () {
        expect(FileDroidTheme.badgeColorForExtension('doc'), FileDroidTheme.accentCyan);
        expect(FileDroidTheme.badgeColorForExtension('docx'), FileDroidTheme.accentCyan);
      });

      test('returns greenSuccess for spreadsheets', () {
        for (final ext in ['xls', 'xlsx', 'csv']) {
          expect(FileDroidTheme.badgeColorForExtension(ext), FileDroidTheme.greenSuccess,
              reason: '$ext should be greenSuccess');
        }
      });

      test('returns amberWarning for presentations', () {
        expect(FileDroidTheme.badgeColorForExtension('ppt'), FileDroidTheme.amberWarning);
        expect(FileDroidTheme.badgeColorForExtension('pptx'), FileDroidTheme.amberWarning);
      });

      test('returns accentTeal for archives', () {
        for (final ext in ['zip', 'rar', '7z', 'tar', 'gz']) {
          expect(FileDroidTheme.badgeColorForExtension(ext), FileDroidTheme.accentTeal,
              reason: '$ext should be accentTeal');
        }
      });

      test('returns greenSuccess for apk', () {
        expect(FileDroidTheme.badgeColorForExtension('apk'), FileDroidTheme.greenSuccess);
      });

      test('returns accentCyan for text/code files', () {
        for (final ext in ['txt', 'log', 'md', 'json', 'xml', 'html', 'css', 'js']) {
          expect(FileDroidTheme.badgeColorForExtension(ext), FileDroidTheme.accentCyan,
              reason: '$ext should be accentCyan');
        }
      });

      test('returns accentTeal for unknown extensions', () {
        expect(FileDroidTheme.badgeColorForExtension('xyz'), FileDroidTheme.accentTeal);
        expect(FileDroidTheme.badgeColorForExtension(''), FileDroidTheme.accentTeal);
      });

      test('is case-insensitive', () {
        expect(FileDroidTheme.badgeColorForExtension('JPG'), FileDroidTheme.purple);
        expect(FileDroidTheme.badgeColorForExtension('Mp4'), FileDroidTheme.roseError);
      });
    });

    group('badgeTextForExtension', () {
      test('returns IM for image extensions', () {
        for (final ext in ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg', 'heic', 'heif']) {
          expect(FileDroidTheme.badgeTextForExtension(ext), 'IM', reason: ext);
        }
      });

      test('returns VD for video extensions', () {
        for (final ext in ['mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm']) {
          expect(FileDroidTheme.badgeTextForExtension(ext), 'VD', reason: ext);
        }
      });

      test('returns AU for audio extensions', () {
        for (final ext in ['mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a', 'm3u']) {
          expect(FileDroidTheme.badgeTextForExtension(ext), 'AU', reason: ext);
        }
      });

      test('returns PD for pdf', () {
        expect(FileDroidTheme.badgeTextForExtension('pdf'), 'PD');
      });

      test('returns DO for doc/docx', () {
        expect(FileDroidTheme.badgeTextForExtension('doc'), 'DO');
        expect(FileDroidTheme.badgeTextForExtension('docx'), 'DO');
      });

      test('returns XL for spreadsheets', () {
        for (final ext in ['xls', 'xlsx', 'csv']) {
          expect(FileDroidTheme.badgeTextForExtension(ext), 'XL', reason: ext);
        }
      });

      test('returns PT for presentations', () {
        expect(FileDroidTheme.badgeTextForExtension('ppt'), 'PT');
        expect(FileDroidTheme.badgeTextForExtension('pptx'), 'PT');
      });

      test('returns ZP for archives', () {
        for (final ext in ['zip', 'rar', '7z', 'tar', 'gz']) {
          expect(FileDroidTheme.badgeTextForExtension(ext), 'ZP', reason: ext);
        }
      });

      test('returns AP for apk', () {
        expect(FileDroidTheme.badgeTextForExtension('apk'), 'AP');
      });

      test('returns TX for text/code files', () {
        for (final ext in ['txt', 'log', 'md', 'json', 'xml', 'html', 'css', 'js']) {
          expect(FileDroidTheme.badgeTextForExtension(ext), 'TX', reason: ext);
        }
      });

      test('returns first 2 chars uppercase for unknown 2+ char extension', () {
        expect(FileDroidTheme.badgeTextForExtension('dart'), 'DA');
        expect(FileDroidTheme.badgeTextForExtension('py'), 'PY');
      });

      test('returns single char uppercase for 1-char extension', () {
        expect(FileDroidTheme.badgeTextForExtension('c'), 'C');
      });

      test('returns empty for empty extension', () {
        expect(FileDroidTheme.badgeTextForExtension(''), '');
      });
    });

    group('selectionDecoration', () {
      test('returns BoxDecoration with gradient', () {
        final dec = FileDroidTheme.selectionDecoration();
        expect(dec, isA<BoxDecoration>());
        expect(dec.gradient, isNotNull);
        expect(dec.border, isNotNull);
      });
    });

    group('deviceCardDecoration', () {
      test('returns BoxDecoration with gradient and border radius', () {
        final dec = FileDroidTheme.deviceCardDecoration();
        expect(dec, isA<BoxDecoration>());
        expect(dec.gradient, isNotNull);
        expect(dec.borderRadius, isNotNull);
        expect(dec.border, isNotNull);
      });
    });

    group('glassDecoration', () {
      test('returns decoration with defaults', () {
        final dec = FileDroidTheme.glassDecoration();
        expect(dec, isA<BoxDecoration>());
        expect(dec.borderRadius, BorderRadius.circular(12));
        expect(dec.border, isNotNull);
      });

      test('returns decoration without border when showBorder is false', () {
        final dec = FileDroidTheme.glassDecoration(showBorder: false);
        expect(dec.border, isNull);
      });

      test('uses custom borderRadius', () {
        final dec = FileDroidTheme.glassDecoration(borderRadius: 20);
        expect(dec.borderRadius, BorderRadius.circular(20));
      });

      test('uses custom color', () {
        final dec = FileDroidTheme.glassDecoration(color: Colors.red);
        expect(dec.color, isNotNull);
      });
    });

    group('sectionLabelStyle', () {
      test('returns TextStyle with correct properties', () {
        final style = FileDroidTheme.sectionLabelStyle();
        expect(style.fontSize, 10);
        expect(style.fontWeight, FontWeight.w600);
        expect(style.letterSpacing, 0.8);
        expect(style.color, FileDroidTheme.textTertiary);
      });
    });

    group('constants', () {
      test('dirBadgeColor is accentIndigo', () {
        expect(FileDroidTheme.dirBadgeColor, FileDroidTheme.accentIndigo);
      });

      test('quickAccessColors has all 7 entries', () {
        expect(FileDroidTheme.quickAccessColors.length, 7);
        expect(FileDroidTheme.quickAccessColors.containsKey('Internal Storage'), isTrue);
        expect(FileDroidTheme.quickAccessColors.containsKey('Downloads'), isTrue);
        expect(FileDroidTheme.quickAccessColors.containsKey('Camera'), isTrue);
        expect(FileDroidTheme.quickAccessColors.containsKey('Pictures'), isTrue);
        expect(FileDroidTheme.quickAccessColors.containsKey('Documents'), isTrue);
        expect(FileDroidTheme.quickAccessColors.containsKey('Music'), isTrue);
        expect(FileDroidTheme.quickAccessColors.containsKey('Movies'), isTrue);
      });
    });

    group('gradients', () {
      test('storageGradient has 3 colors', () {
        expect(FileDroidTheme.storageGradient, isA<LinearGradient>());
        expect(FileDroidTheme.storageGradient.colors.length, 3);
        expect(FileDroidTheme.storageGradient.colors[0], FileDroidTheme.accentIndigo);
        expect(FileDroidTheme.storageGradient.colors[1], FileDroidTheme.accentCyan);
        expect(FileDroidTheme.storageGradient.colors[2], FileDroidTheme.greenSuccess);
      });

      test('progressGradient has 2 colors', () {
        expect(FileDroidTheme.progressGradient, isA<LinearGradient>());
        expect(FileDroidTheme.progressGradient.colors.length, 2);
        expect(FileDroidTheme.progressGradient.colors[0], FileDroidTheme.accentIndigo);
        expect(FileDroidTheme.progressGradient.colors[1], FileDroidTheme.accentCyan);
      });

      test('uploadGradient has 2 colors', () {
        expect(FileDroidTheme.uploadGradient, isA<LinearGradient>());
        expect(FileDroidTheme.uploadGradient.colors.length, 2);
        expect(FileDroidTheme.uploadGradient.colors[0], FileDroidTheme.accentIndigo);
      });

      test('downloadGradient has 2 colors', () {
        expect(FileDroidTheme.downloadGradient, isA<LinearGradient>());
        expect(FileDroidTheme.downloadGradient.colors.length, 2);
        expect(FileDroidTheme.downloadGradient.colors[0], FileDroidTheme.accentCyan);
        expect(FileDroidTheme.downloadGradient.colors[1], FileDroidTheme.accentTeal);
      });
    });

    group('macosTheme', () {
      test('returns MacosThemeData with dark brightness', () {
        final theme = FileDroidTheme.macosTheme();
        expect(theme, isA<MacosThemeData>());
        expect(theme.brightness, Brightness.dark);
      });

      test('uses accentIndigo as primary color', () {
        final theme = FileDroidTheme.macosTheme();
        expect(theme.primaryColor, FileDroidTheme.accentIndigo);
      });

      test('uses bgPrimary as canvas color', () {
        final theme = FileDroidTheme.macosTheme();
        expect(theme.canvasColor, FileDroidTheme.bgPrimary);
      });
    });
  });
}
