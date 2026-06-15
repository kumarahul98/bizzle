import 'dart:io';

class TripStatePersister {
  TripStatePersister({
    Future<Directory> Function()? directoryProvider,
  });

  Future<Map<String, dynamic>?> loadState() async {
    return null;
  }

  Future<void> saveState(Map<String, dynamic> state) async {
  }

  Future<void> clear() async {
  }
}
