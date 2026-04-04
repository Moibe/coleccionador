import 'dart:convert';
import 'package:flutter/services.dart';

/// Representa una página del álbum con rango de estampas
class AlbumPage {
  final int pageNumber;
  final int start;
  final int end;

  AlbumPage({required this.pageNumber, required this.start, required this.end});

  int get size => end - start + 1;
}

/// Servicio para manejar la configuración de la app desde config.json
class ConfigService {
  static late Map<String, dynamic> _config;
  static late List<AlbumPage> _pages;

  /// Inicializar la configuración. Debe llamarse antes de usar el servicio.
  static Future<void> init() async {
    final jsonString = await rootBundle.loadString('assets/config.json');
    _config = jsonDecode(jsonString) as Map<String, dynamic>;
    _buildPages();
  }

  /// Construir las páginas del álbum
  static void _buildPages() {
    final total = getTotalStamps();

    if (_config.containsKey('pages')) {
      // Páginas personalizadas definidas en config
      final List<dynamic> pagesJson = _config['pages'];
      _pages = pagesJson.asMap().entries.map((entry) {
        final p = entry.value;
        return AlbumPage(
          pageNumber: entry.key + 1,
          start: p['start'] as int,
          end: p['end'] as int,
        );
      }).toList();
    } else {
      // Páginas uniformes basadas en default_page_size
      final pageSize = getDefaultPageSize();
      _pages = [];
      for (int i = 0; i < total; i += pageSize) {
        final start = i + 1;
        final end = (i + pageSize > total) ? total : i + pageSize;
        _pages.add(AlbumPage(
          pageNumber: _pages.length + 1,
          start: start,
          end: end,
        ));
      }
    }
  }

  static int getTotalStamps() => _config['total_stamps'] as int;
  static int getDefaultPageSize() => _config['default_page_size'] as int;
  static String getAppTitle() => _config['app_title'] as String;
  static String getAppName() => _config['app_name'] as String;
  static String getDefaultCollection() => _config['default_collection'] as String;
  static List<AlbumPage> getPages() => _pages;
  static int getTotalPages() => _pages.length;
}
