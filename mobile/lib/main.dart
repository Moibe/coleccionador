import 'package:flutter/material.dart';
import 'services/storage_service.dart';
import 'services/config_service.dart';
import 'services/exchange_service.dart';
import 'screens/exchange_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ConfigService.init();
  await StorageService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: ConfigService.getAppTitle(),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

/// Pantalla principal con navbar
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storage = StorageService();
  int _selectedTab = 0;
  Map<int, int> _ownedMap = {};

  @override
  void initState() {
    super.initState();
    _loadOwned();
  }

  Future<void> _loadOwned() async {
    final owned = await _storage.getOwnedMap();
    setState(() => _ownedMap = owned);
  }

  Future<void> _tap(int stampId) async {
    final newCount = await _storage.tapStamp(stampId);
    setState(() => _ownedMap[stampId] = newCount);
  }

  Future<void> _decrement(int stampId) async {
    final result = await _storage.decrementStamp(stampId);
    setState(() {
      if (result == null) {
        _ownedMap.remove(stampId);
      } else {
        _ownedMap[stampId] = result;
      }
    });
  }

  Future<void> _remove(int stampId) async {
    await _storage.removeStamp(stampId);
    setState(() => _ownedMap.remove(stampId));
  }

  Widget _buildTab() {
    switch (_selectedTab) {
      case 0:
        return const StatsTab();
      case 1:
        return CollectorTab(
          ownedMap: _ownedMap,
          onTap: _tap,
          onDecrement: _decrement,
          onRemove: _remove,
        );
      case 2:
        return RepeatsTab(
          ownedMap: _ownedMap,
          onTap: _tap,
          onDecrement: _decrement,
        );
      case 3:
        return ExchangeTab(
          ownedMap: _ownedMap,
          qrData: ExchangeService.encode(
            _ownedMap,
            totalStamps: ConfigService.getTotalStamps(),
          ),
        );
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(ConfigService.getAppTitle()),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _buildTab(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) => setState(() => _selectedTab = index),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Estadísticas',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Coleccionador',
          ),
          NavigationDestination(
            icon: Icon(Icons.copy_outlined),
            selectedIcon: Icon(Icons.copy),
            label: 'Repetidas',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz_outlined),
            selectedIcon: Icon(Icons.swap_horiz),
            label: 'Intercambio',
          ),
        ],
      ),
    );
  }
}

/// Tab del coleccionador (grid de estampas)
class CollectorTab extends StatefulWidget {
  final Map<int, int> ownedMap;
  final Future<void> Function(int) onTap;
  final Future<void> Function(int) onDecrement;
  final Future<void> Function(int) onRemove;

  const CollectorTab({
    super.key,
    required this.ownedMap,
    required this.onTap,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  State<CollectorTab> createState() => _CollectorTabState();
}

class _CollectorTabState extends State<CollectorTab> {
  late List<AlbumPage> _pages;
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pages = ConfigService.getPages();
  }

  AlbumPage get _currentPage => _pages[_currentPageIndex];

  @override
  Widget build(BuildContext context) {
    final totalStamps = ConfigService.getTotalStamps();
    final pageStampIds = List.generate(
      _currentPage.size,
      (i) => _currentPage.start + i,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Tienes ${widget.ownedMap.length} de $totalStamps estampitas',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: _currentPageIndex > 0
                  ? () => setState(() => _currentPageIndex--)
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              'Página ${_currentPage.pageNumber} de ${_pages.length}  (${_currentPage.start}-${_currentPage.end})',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            IconButton(
              onPressed: _currentPageIndex < _pages.length - 1
                  ? () => setState(() => _currentPageIndex++)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
              childAspectRatio: 1,
            ),
            itemCount: pageStampIds.length,
            itemBuilder: (context, index) {
              final stampId = pageStampIds[index];
              final isOwned = widget.ownedMap.containsKey(stampId);
              final repeats = widget.ownedMap[stampId] ?? 0;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isOwned
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isOwned
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade400,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2, right: 4),
                        child: repeats > 0
                            ? Container(
                                padding: const EdgeInsets.all(2),
                                constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                                decoration: const BoxDecoration(
                                  color: Colors.orange,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$repeats',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : const SizedBox(height: 14),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => widget.onTap(stampId),
                      onLongPress: isOwned ? () => widget.onRemove(stampId) : null,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOwned ? Icons.check_circle : Icons.circle_outlined,
                            color: isOwned ? Colors.white : Colors.grey,
                            size: 20,
                          ),
                          Text(
                            '$stampId',
                            style: TextStyle(
                              color: isOwned ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (isOwned)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2, left: 6, right: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () => widget.onDecrement(stampId),
                              child: const Text(
                                '-',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => widget.onTap(stampId),
                              child: const Text(
                                '+',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const SizedBox(height: 16),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Tab de repetidas
class RepeatsTab extends StatelessWidget {
  final Map<int, int> ownedMap;
  final Future<void> Function(int) onTap;
  final Future<void> Function(int) onDecrement;

  const RepeatsTab({
    super.key,
    required this.ownedMap,
    required this.onTap,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final repeatedEntries = ownedMap.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final totalRepeats = repeatedEntries.fold<int>(0, (sum, e) => sum + e.value);

    if (repeatedEntries.isEmpty) {
      return const Center(
        child: Text(
          'No tienes estampitas repetidas',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '${repeatedEntries.length} estampitas repetidas ($totalRepeats en total)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: repeatedEntries.length,
            itemBuilder: (context, index) {
              final entry = repeatedEntries[index];
              final stampId = entry.key;
              final repeats = entry.value;
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '$stampId',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                title: Text('Estampa #$stampId'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => onDecrement(stampId),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('-', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$repeats',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => onTap(stampId),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('+', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Tab de Estadísticas (vacío por ahora)
class StatsTab extends StatelessWidget {
  const StatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Estadísticas'),
    );
  }
}
