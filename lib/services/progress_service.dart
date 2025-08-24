import 'package:hive/hive.dart';

class ProgressService {
  static const String _boxName = 'progressBox';
  static Box<dynamic>? _box;

  static Future<void> init() async {
    _box ??= await Hive.openBox<dynamic>(_boxName);
  }

  static dynamic read(String gameId, [String key = 'data']) {
    final val = _box?.get('${gameId}_$key');
    return val;
  }

  static Future<void> write(String gameId, dynamic value, [String key = 'data']) async {
    await _box?.put('${gameId}_$key', value);
  }

  static Future<void> clearGame(String gameId) async {
    final keys = _box?.keys.where((k) => k.toString().startsWith('$gameId')).toList() ?? [];
    for (final k in keys) {
      await _box?.delete(k);
    }
  }
}
