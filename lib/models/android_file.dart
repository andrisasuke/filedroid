import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/theme.dart';

class AndroidFile {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime? modified;
  final String? permissions;
  final bool isSymlink;

  const AndroidFile({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size = 0,
    this.modified,
    this.permissions,
    this.isSymlink = false,
  });

  String get extension {
    if (isDirectory) return '';
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == name.length - 1) return '';
    return name.substring(dotIndex + 1).toLowerCase();
  }

  String get formattedSize {
    if (isDirectory) return '--';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(0)} KB';
    if (size < 1024 * 1024 * 1024) {
      final mb = size / (1024 * 1024);
      return '${mb < 10 ? mb.toStringAsFixed(1) : mb.toStringAsFixed(0)} MB';
    }
    final gb = size / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(1)} GB';
  }

  String get formattedDate {
    if (modified == null) return '--';
    return DateFormat('MMM d, yyyy').format(modified!);
  }

  String get badgeText {
    if (isDirectory) {
      return name.length >= 2
          ? name.substring(0, 2).toUpperCase()
          : name.toUpperCase();
    }
    return FileBeamTheme.badgeTextForExtension(extension);
  }

  Color get badgeColor {
    if (isDirectory) return FileBeamTheme.dirBadgeColor;
    return FileBeamTheme.badgeColorForExtension(extension);
  }
}
