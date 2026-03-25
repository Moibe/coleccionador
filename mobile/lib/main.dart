import 'package:flutter/material.dart';
import 'services/storage_service.dart';
import 'models/stamp.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Coleccionador',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const StampTestScreen(),
    );
  }
}

/// Pantalla de prueba para verificar que Hive funciona correctamente
class StampTestScreen extends StatefulWidget {
  const StampTestScreen({super.key});

  @override
  State<StampTestScreen> createState() => _StampTestScreenState();
}

class _StampTestScreenState extends State<StampTestScreen> {
  final StorageService _storage = StorageService();
  List<Stamp> _stamps = [];

  @override
  void initState() {
    super.initState();
    _loadTestData();
  }

  /// Carga stamps de prueba si no hay datos
  Future<void> _loadTestData() async {
    final saved = await _storage.getStamps();
    if (saved.isEmpty) {
      // Stamps de prueba para verificar Hive
      final testStamps = List.generate(
        12,
        (i) => Stamp(
          id: i + 1,
          name: 'Estampita ${i + 1}',
          collection: 'Album 1',
        ),
      );
      await _storage.saveStamps(testStamps);
    }
    final stamps = await _storage.getStamps();
    setState(() => _stamps = stamps);
  }

  /// Marcar/desmarcar estampita
  Future<void> _toggle(int stampId) async {
    await _storage.toggleOwned(stampId);
    final stamps = await _storage.getStamps();
    setState(() => _stamps = stamps);
  }

  @override
  Widget build(BuildContext context) {
    final owned = _stamps.where((s) => s.owned).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coleccionador'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Tienes $owned de ${_stamps.length} estampitas',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _stamps.length,
              itemBuilder: (context, index) {
                final stamp = _stamps[index];
                return GestureDetector(
                  onTap: () => _toggle(stamp.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: stamp.owned
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: stamp.owned
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade400,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          stamp.owned ? Icons.check_circle : Icons.circle_outlined,
                          color: stamp.owned ? Colors.white : Colors.grey,
                          size: 28,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${stamp.id}',
                          style: TextStyle(
                            color: stamp.owned ? Colors.white : Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
