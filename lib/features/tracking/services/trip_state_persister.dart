import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class TripStatePersister {
  final Future<Directory> Function()? _directoryProvider;

  TripStatePersister({
    Future<Directory> Function()? directoryProvider,
  }) : _directoryProvider = directoryProvider;

  Future<File> get _file async {
    final dir = _directoryProvider != null
        ? await _directoryProvider!()
        : await getApplicationDocumentsDirectory();
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
