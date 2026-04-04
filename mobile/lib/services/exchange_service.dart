import 'dart:convert';
import 'dart:typed_data';

/// Codifica/decodifica el ownedMap para transmitirlo vía QR.
///
/// Formato binario compacto (funciona en web y nativo):
///   [version:1][totalStamps:2][bitmap:ceil(total/8)][repeatCount:2][entries:3*N]
///
/// - bitmap: bit i = estampa (i+1) está poseída
/// - entries: [stampId:2][count:1] solo para estampas con repeats > 0
///
/// Se codifica en base64. Tamaño típico: ~200-1500 bytes.
class ExchangeService {
  static const int _version = 1;

  /// Codifica un ownedMap en un string base64 apto para QR.
  static String encode(Map<int, int> ownedMap, {required int totalStamps}) {
    final bitmapBytes = (totalStamps + 7) ~/ 8;
    final bitmap = Uint8List(bitmapBytes);

    // Construir bitmap y lista de repetidas
    final repeats = <MapEntry<int, int>>[];
    for (final entry in ownedMap.entries) {
      final id = entry.key;
      if (id >= 1 && id <= totalStamps) {
        bitmap[(id - 1) ~/ 8] |= (1 << ((id - 1) % 8));
        if (entry.value > 0) {
          repeats.add(entry);
        }
      }
    }
    repeats.sort((a, b) => a.key.compareTo(b.key));

    // Header(3) + bitmap + repeatCount(2) + entries(3 each)
    final totalSize = 3 + bitmapBytes + 2 + repeats.length * 3;
    final buffer = ByteData(totalSize);
    var offset = 0;

    // Header
    buffer.setUint8(offset++, _version);
    buffer.setUint16(offset, totalStamps, Endian.little);
    offset += 2;

    // Bitmap
    for (var i = 0; i < bitmapBytes; i++) {
      buffer.setUint8(offset++, bitmap[i]);
    }

    // Repeat count
    buffer.setUint16(offset, repeats.length, Endian.little);
    offset += 2;

    // Repeat entries
    for (final entry in repeats) {
      buffer.setUint16(offset, entry.key, Endian.little);
      offset += 2;
      buffer.setUint8(offset++, entry.value.clamp(0, 255));
    }

    return base64Encode(buffer.buffer.asUint8List());
  }

  /// Decodifica el string del QR de vuelta a un ownedMap.
  /// Retorna null si el formato es inválido.
  static Map<int, int>? decode(String data) {
    try {
      final bytes = base64Decode(data);
      if (bytes.length < 3) return null;

      final buffer = ByteData.sublistView(Uint8List.fromList(bytes));
      var offset = 0;

      final version = buffer.getUint8(offset++);
      if (version != _version) return null;

      final totalStamps = buffer.getUint16(offset, Endian.little);
      offset += 2;

      final bitmapBytes = (totalStamps + 7) ~/ 8;
      if (bytes.length < 3 + bitmapBytes + 2) return null;

      // Leer bitmap
      final result = <int, int>{};
      for (var i = 0; i < bitmapBytes; i++) {
        final byte = buffer.getUint8(offset++);
        for (var bit = 0; bit < 8; bit++) {
          if (byte & (1 << bit) != 0) {
            final stampId = i * 8 + bit + 1;
            if (stampId <= totalStamps) {
              result[stampId] = 0;
            }
          }
        }
      }

      // Leer repetidas
      final repeatCount = buffer.getUint16(offset, Endian.little);
      offset += 2;

      if (bytes.length < offset + repeatCount * 3) return null;

      for (var i = 0; i < repeatCount; i++) {
        final id = buffer.getUint16(offset, Endian.little);
        offset += 2;
        final count = buffer.getUint8(offset++);
        if (id >= 1 && id <= totalStamps) {
          result[id] = count;
        }
      }

      return result;
    } catch (_) {
      return null;
    }
  }

  /// Calcula la comparación entre dos usuarios.
  static ExchangeResult compare({
    required Map<int, int> myMap,
    required Map<int, int> theirMap,
    required int totalStamps,
  }) {
    final iCanGive = <int, int>{};
    final theyCanGive = <int, int>{};

    for (var id = 1; id <= totalStamps; id++) {
      final myRepeats = myMap.containsKey(id) ? myMap[id]! : -1;
      final theyHave = theirMap.containsKey(id);

      // Yo tengo repetidas y el otro NO la tiene
      if (myRepeats > 0 && !theyHave) {
        iCanGive[id] = myRepeats;
      }

      final theirRepeats = theirMap.containsKey(id) ? theirMap[id]! : -1;
      final iHave = myMap.containsKey(id);

      // El otro tiene repetidas y yo NO la tengo
      if (theirRepeats > 0 && !iHave) {
        theyCanGive[id] = theirRepeats;
      }
    }

    return ExchangeResult(
      iCanGive: iCanGive,
      theyCanGive: theyCanGive,
      totalStamps: totalStamps,
      myOwned: myMap.length,
      theirOwned: theirMap.length,
    );
  }
}

class ExchangeResult {
  /// Estampas que yo tengo repetidas y el otro necesita (yo le doy)
  final Map<int, int> iCanGive;

  /// Estampas que el otro tiene repetidas y yo necesito (me da)
  final Map<int, int> theyCanGive;

  final int totalStamps;
  final int myOwned;
  final int theirOwned;

  ExchangeResult({
    required this.iCanGive,
    required this.theyCanGive,
    required this.totalStamps,
    required this.myOwned,
    required this.theirOwned,
  });

  int get myMissing => totalStamps - myOwned;
  int get theirMissing => totalStamps - theirOwned;

  /// Cuántas estampas se pueden intercambiar mutuamente
  int get mutualExchangeCount {
    final minGive = iCanGive.length;
    final minReceive = theyCanGive.length;
    return minGive < minReceive ? minGive : minReceive;
  }
}
