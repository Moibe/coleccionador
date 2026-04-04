import 'package:hive_flutter/hive_flutter.dart';

/// Servicio para manejar el almacenamiento local con Hive.
/// Guarda los IDs de las estampas que el usuario posee y cuántas repetidas tiene.
/// Valor almacenado: 0 = la tiene (sin repetidas), 1+ = cantidad de repetidas.
class StorageService {
  static const String _ownedBox = 'owned_stamps';

  /// Inicializar Hive. Debe llamarse antes de usar el servicio.
  static Future<void> init() async {
    await Hive.initFlutter();
  }

  /// Abrir la caja de estampas poseídas.
  Future<Box> _openBox() async {
    return await Hive.openBox(_ownedBox);
  }

  /// Obtener mapa de estampas poseídas con su conteo de repetidas.
  Future<Map<int, int>> getOwnedMap() async {
    final box = await _openBox();
    final map = <int, int>{};
    for (final key in box.keys) {
      final value = box.get(key);
      // Migrar valores antiguos (true) a 0 repetidas
      map[key as int] = (value is int) ? value : 0;
    }
    return map;
  }

  /// Tap en una estampa: si no la tiene, la marca. Si ya la tiene, suma +1 repetida.
  /// Retorna el nuevo conteo de repetidas (0 = recién marcada, 1+ = repetidas).
  Future<int> tapStamp(int stampId) async {
    final box = await _openBox();
    if (box.containsKey(stampId)) {
      final current = box.get(stampId);
      final count = (current is int) ? current : 0;
      final newCount = count + 1;
      await box.put(stampId, newCount);
      return newCount;
    } else {
      await box.put(stampId, 0);
      return 0;
    }
  }

  /// Desmarcar una estampa (quitar de la colección).
  Future<void> removeStamp(int stampId) async {
    final box = await _openBox();
    await box.delete(stampId);
  }

  /// Decrementar repetidas. Si llega a 0 repetidas, mantiene la estampa como poseída.
  /// Si ya tiene 0 repetidas, la desmarca completamente.
  /// Retorna null si se desmarcó, o el nuevo conteo.
  Future<int?> decrementStamp(int stampId) async {
    final box = await _openBox();
    if (!box.containsKey(stampId)) return null;
    final current = box.get(stampId);
    final count = (current is int) ? current : 0;
    if (count <= 0) {
      await box.delete(stampId);
      return null;
    } else {
      final newCount = count - 1;
      await box.put(stampId, newCount);
      return newCount;
    }
  }

  /// Borrar todos los datos locales.
  Future<void> clearAll() async {
    final box = await _openBox();
    await box.clear();
  }
}
