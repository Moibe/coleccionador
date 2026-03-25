/// Modelo de una estampita
class Stamp {
  final int id;
  final String name;
  final String collection;
  bool owned;

  Stamp({
    required this.id, 
    required this.name,
    required this.collection,
    this.owned = false,
  });

  /// Crear desde JSON (de la API)
  factory Stamp.fromJson(Map<String, dynamic> json) {
    return Stamp(
      id: json['id'] as int,
      name: json['name'] as String,
      collection: json['collection'] as String,
      owned: json['owned'] as bool? ?? false,
    );
  }

  /// Convertir a JSON (para enviar a la API)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'collection': collection,
      'owned': owned,
    };
  }

  /// Crear una copia con cambios
  Stamp copyWith({
    int? id,
    String? name,
    String? collection,
    bool? owned,
  }) {
    return Stamp(
      id: id ?? this.id,
      name: name ?? this.name,
      collection: collection ?? this.collection,
      owned: owned ?? this.owned,
    );
  }
}
 