import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class TripStatePersister {
  final Future<Directory> Function()? _directoryProvider;

  TripStatePersister({
    Future<Directory> Function()? directoryProvider,
  }) : _directoryProvider = directoryProvider;

  // Resolved once and reused: saveState runs on the GPS hot path, and
  // getApplicationDocumentsDirectory() is a platform-channel round trip that
  // never changes for the life of the process. Caching the Future (not the
  // File) lets concurrent first callers share a single resolution.
  Future<File>? _cachedFile;

  Future<File> get _file => _cachedFile ??= _resolveFile();

  Future<File> _resolveFile() async {
    Directory dir;
    try {
      dir = _directoryProvider != null
          ? await _directoryProvider()
          : await getApplicationDocumentsDirectory();
    } catch (e) {
      dir = Directory.systemTemp;
    }
    return File('${dir.path}/active_trip.json');
  }

  Future<Map<String, dynamic>?> loadState() async {
    final file = await _file;
    if (!await file.exists()) {
      return null;
    }
    try {
      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  Future<void> saveState(Map<String, dynamic> state) async {
    final file = await _file;
    await file.writeAsString(jsonEncode(state));
  }

  Future<void> clear() async {
    final file = await _file;
    if (await file.exists()) {
      await file.delete();
    }
  }
}
