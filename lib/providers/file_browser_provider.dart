import 'package:flutter/foundation.dart';
import '../models/android_file.dart';
import '../services/adb_service.dart';

enum SortMode { name, size, date, type }

class FileBrowserProvider extends ChangeNotifier {
  final AdbService _adb;

  String _currentPath = '/sdcard';
  List<AndroidFile> _files = [];
  List<AndroidFile> _allFiles = []; // before filtering
  final List<String> _pathHistory = ['/sdcard'];
  int _historyIndex = 0;
  final Set<String> _selectedPaths = {};
  bool _showHidden = false;
  SortMode _sortMode = SortMode.name;
  bool _sortAscending = true;
  bool _isLoading = false;
  String? _error;

  FileBrowserProvider(this._adb);

  String get currentPath => _currentPath;
  List<AndroidFile> get files => _files;
  Set<String> get selectedPaths => _selectedPaths;
  bool get showHidden => _showHidden;
  SortMode get sortMode => _sortMode;
  bool get sortAscending => _sortAscending;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get canGoBack => _historyIndex > 0;
  bool get canGoForward => _historyIndex < _pathHistory.length - 1;
  bool get isAtRoot => _currentPath == '/';
  bool get hasSelection => _selectedPaths.isNotEmpty;
  int get selectionCount => _selectedPaths.length;

  List<AndroidFile> get selectedFiles =>
      _files.where((f) => _selectedPaths.contains(f.path)).toList();

  List<String> get breadcrumbs {
    if (_currentPath == '/') return ['/'];
    final parts = _currentPath.split('/').where((p) => p.isNotEmpty).toList();
    return ['/', ...parts];
  }

  String pathForBreadcrumb(int index) {
    if (index == 0) return '/';
    final parts = _currentPath.split('/').where((p) => p.isNotEmpty).toList();
    return '/${parts.take(index).join('/')}';
  }

  String get contextLabel {
    if (_currentPath == '/sdcard') return 'Internal Storage';
    final parts = _currentPath.split('/').where((p) => p.isNotEmpty).toList();
    // Skip "sdcard" prefix for display
    if (parts.isNotEmpty && parts.first == 'sdcard') {
      return parts.skip(1).join(' / ');
    }
    return parts.join(' / ');
  }

  Future<void> navigateTo(String path) async {
    _isLoading = true;
    _error = null;
    _selectedPaths.clear();
    notifyListeners();

    try {
      final rawFiles = await _adb.listFiles(path);
      _currentPath = path;
      _allFiles = rawFiles;
      _applyFilterAndSort();

      // Update history
      if (_historyIndex < _pathHistory.length - 1) {
        _pathHistory.removeRange(_historyIndex + 1, _pathHistory.length);
      }
      _pathHistory.add(path);
      _historyIndex = _pathHistory.length - 1;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> navigateUp() async {
    if (_currentPath == '/') return;
    final parentIdx = _currentPath.lastIndexOf('/');
    final parent =
        parentIdx <= 0 ? '/' : _currentPath.substring(0, parentIdx);
    await navigateTo(parent);
  }

  Future<void> goBack() async {
    if (!canGoBack) return;
    _historyIndex--;
    final path = _pathHistory[_historyIndex];
    _isLoading = true;
    _error = null;
    _selectedPaths.clear();
    notifyListeners();

    try {
      final rawFiles = await _adb.listFiles(path);
      _currentPath = path;
      _allFiles = rawFiles;
      _applyFilterAndSort();
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> goForward() async {
    if (!canGoForward) return;
    _historyIndex++;
    final path = _pathHistory[_historyIndex];
    _isLoading = true;
    _error = null;
    _selectedPaths.clear();
    notifyListeners();

    try {
      final rawFiles = await _adb.listFiles(path);
      _currentPath = path;
      _allFiles = rawFiles;
      _applyFilterAndSort();
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final rawFiles = await _adb.listFiles(_currentPath);
      _allFiles = rawFiles;
      _applyFilterAndSort();
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  void toggleSelection(AndroidFile file) {
    if (_selectedPaths.contains(file.path)) {
      _selectedPaths.remove(file.path);
    } else {
      _selectedPaths.add(file.path);
    }
    notifyListeners();
  }

  void selectAll() {
    _selectedPaths.addAll(
        _files.where((f) => !f.isDirectory).map((f) => f.path));
    notifyListeners();
  }

  void deselectAll() {
    _selectedPaths.clear();
    notifyListeners();
  }

  void toggleHidden() {
    _showHidden = !_showHidden;
    _applyFilterAndSort();
    notifyListeners();
  }

  void setSortMode(SortMode mode) {
    if (_sortMode == mode) {
      _sortAscending = !_sortAscending;
    } else {
      _sortMode = mode;
      _sortAscending = true;
    }
    _applyFilterAndSort();
    notifyListeners();
  }

  void _applyFilterAndSort() {
    var filtered = _allFiles.toList();

    // Hide dotfiles unless showHidden
    if (!_showHidden) {
      filtered = filtered.where((f) => !f.name.startsWith('.')).toList();
    }

    // Sort: dirs first always, then by sortMode
    filtered.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;

      int cmp;
      switch (_sortMode) {
        case SortMode.name:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case SortMode.size:
          cmp = a.size.compareTo(b.size);
        case SortMode.date:
          final aDate = a.modified ?? DateTime(1970);
          final bDate = b.modified ?? DateTime(1970);
          cmp = aDate.compareTo(bDate);
        case SortMode.type:
          cmp = a.extension.compareTo(b.extension);
      }
      return _sortAscending ? cmp : -cmp;
    });

    _files = filtered;
  }

  Future<bool> createFolder(String name) async {
    final path = _currentPath == '/' ? '/$name' : '$_currentPath/$name';
    final ok = await _adb.createDirectory(path);
    if (ok) await refresh();
    return ok;
  }

  Future<bool> renameItem(AndroidFile file, String newName) async {
    final parentIdx = file.path.lastIndexOf('/');
    final parent = parentIdx <= 0 ? '/' : file.path.substring(0, parentIdx);
    final newPath = parent == '/' ? '/$newName' : '$parent/$newName';
    final ok = await _adb.rename(file.path, newPath);
    if (ok) await refresh();
    return ok;
  }

  Future<void> deleteItems(List<AndroidFile> items) async {
    for (final item in items) {
      await _adb.delete(item.path, recursive: item.isDirectory);
    }
    _selectedPaths.clear();
    await refresh();
  }

  // Quick navigation
  Future<void> goToSdcard() => navigateTo('/sdcard');
  Future<void> goToDownloads() => navigateTo('/sdcard/Download');
  Future<void> goToDCIM() => navigateTo('/sdcard/DCIM');
  Future<void> goToDocuments() => navigateTo('/sdcard/Documents');
  Future<void> goToMusic() => navigateTo('/sdcard/Music');
  Future<void> goToMovies() => navigateTo('/sdcard/Movies');
  Future<void> goToPictures() => navigateTo('/sdcard/Pictures');

  String? get activeQuickAccess {
    if (_currentPath == '/sdcard') return 'Internal Storage';
    if (_currentPath.startsWith('/sdcard/Download')) return 'Downloads';
    if (_currentPath.startsWith('/sdcard/DCIM')) return 'Camera';
    if (_currentPath.startsWith('/sdcard/Pictures')) return 'Pictures';
    if (_currentPath.startsWith('/sdcard/Documents')) return 'Documents';
    if (_currentPath.startsWith('/sdcard/Music')) return 'Music';
    if (_currentPath.startsWith('/sdcard/Movies')) return 'Movies';
    return null;
  }
}
