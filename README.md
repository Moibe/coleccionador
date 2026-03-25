# Coleccionador

App móvil para coleccionar estampitas. Disponible en iOS, Android y Web.

## Estructura

```
coleccionador/
├── mobile/           Flutter app (iOS/Android/Web)
├── shared/           Modelos compartidos y clientes HTTP
├── docs/             Documentación
└── README.md
```

## Tecnología

- **Frontend**: Flutter + Dart
- **Backend**: FastAPI (proyecto separado)
- **Deployment**: Web en DigitalOcean

## Desarrollo

### Mobile (Flutter)
```bash
cd mobile
flutter pub get
flutter run -d web
```

### Shared
Contiene modelos y utilidades compartidas entre frontend y backend.

## Instalación

1. Instalar [Flutter](https://flutter.dev/docs/get-started/install)
2. Instalar dependencias: `flutter pub get`
3. Ejecutar: `flutter run -d web`
