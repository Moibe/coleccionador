import 'package:hive_flutter/hive_flutter.dart';
import '../models/stamp.dart';

/// Servicio para manejar el almacenamiento local con Hive.
/// Guarda los stamps como JSON (Map) en una Box de Hive.
class StorageService {
  static const String _stampsBox = 'stamps';

  /// Inicializar Hive. Debe llamarse antes de usar el servicio.
  static Future<void> init() async {
    await Hive.initFlutter();
  }

  /// Abrir la caja de stamps.
  Future<Box> _openBox() async {
    return await Hive.openBox(_stampsBox);
  }

  /// Guardar una lista de stamps (sobrescribe todo).
  Future<void> saveStamps(List<Stamp> stamps) async {
    final box = await _openBox();
    final Map<String, dynamic> data = {};
    for (final stamp in stamps) {
      data[stamp.id.toString()] = stamp.toJson();
    }
    await box.putAll(data);
  }

  /// Obtener todos los stamps guardados localmente.
  Future<List<Stamp>> getStamps() async {
    final box = await _openBox();
    final List<Stamp> stamps = [];
    for (final key in box.keys) {
      final value = box.get(key);
      if (value != null) {
        stamps.add(Stamp.fromJson(Map<String, dynamic>.from(value)));
      }
    }
    stamps.sort((a, b) => a.id.compareTo(b.id));
    return stamps;
  }

  /// Marcar o desmarcar un stamp como poseído.
  Future<void> toggleOwned(int stampId) async {
    final box = await _openBox();
    final raw = box.get(stampId.toString());
    if (raw != null) {
      final stamp = Stamp.fromJson(Map<String, dynamic>.from(raw));
      stamp.owned = !stamp.owned;
      await box.put(stampId.toString(), stamp.toJson());
    }
  }

  /// Verificar si un stamp específico está guardado.
  Future<bool> isOwned(int stampId) async {
    final box = await _openBox();
    final raw = box.get(stampId.toString());
    if (raw == null) return false;
    return Map<String, dynamic>.from(raw)['owned'] as bool? ?? false;
  }

  /// Borrar todos los datos locales.
  Future<void> clearAll() async {
    final box = await _openBox();
    await box.clear();
  }
}
