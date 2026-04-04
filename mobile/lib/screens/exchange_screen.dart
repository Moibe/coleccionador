import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/exchange_service.dart';
import '../services/config_service.dart';

/// Tab de Intercambio: muestra QR propio + botón para escanear
class ExchangeTab extends StatelessWidget {
  final Map<int, int> ownedMap;
  final String qrData;

  const ExchangeTab({
    super.key,
    required this.ownedMap,
    required this.qrData,
  });

  @override
  Widget build(BuildContext context) {
    final totalStamps = ConfigService.getTotalStamps();
    final repeats = ownedMap.entries.where((e) => e.value > 0).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Tu QR de intercambio',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '${ownedMap.length} estampas · $repeats repetidas',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 250,
              errorCorrectionLevel: QrErrorCorrectLevel.L,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${qrData.length} caracteres',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _openScanner(context, totalStamps),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Escanear QR del otro'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Muestra tu QR al otro coleccionista,\no escanea el suyo para comparar.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
        ],
      ),
    );
  }

  void _openScanner(BuildContext context, int totalStamps) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScannerScreen(
          myMap: ownedMap,
          totalStamps: totalStamps,
        ),
      ),
    );
  }
}

/// Pantalla de escaneo con cámara
class ScannerScreen extends StatefulWidget {
  final Map<int, int> myMap;
  final int totalStamps;

  const ScannerScreen({
    super.key,
    required this.myMap,
    required this.totalStamps,
  });

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _processed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_processed) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final data = barcode.rawValue!;
    final theirMap = ExchangeService.decode(data);

    if (theirMap == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR no válido. Intenta de nuevo.')),
      );
      return;
    }

    _processed = true;
    _controller.stop();

    final result = ExchangeService.compare(
      myMap: widget.myMap,
      theirMap: theirMap,
      totalStamps: widget.totalStamps,
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ExchangeResultScreen(result: result),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear QR'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Apunta la cámara al QR del otro coleccionista',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pantalla de resultados del intercambio
class ExchangeResultScreen extends StatelessWidget {
  final ExchangeResult result;

  const ExchangeResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final iCanGive = result.iCanGive;
    final theyCanGive = result.theyCanGive;
    final iCanGiveIds = iCanGive.keys.toList()..sort();
    final theyCanGiveIds = theyCanGive.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado del intercambio'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Resumen
          _buildSummaryCard(context),
          const SizedBox(height: 16),

          // Matches mutuos
          _buildSectionHeader(
            context,
            icon: Icons.swap_horiz,
            title: 'Intercambio posible',
            subtitle: '${result.mutualExchangeCount} estampas',
            color: Colors.green,
          ),
          const SizedBox(height: 16),

          // Lo que yo le puedo dar
          _buildSectionHeader(
            context,
            icon: Icons.arrow_forward,
            title: 'Tú le puedes dar',
            subtitle: '${iCanGiveIds.length} estampas',
            color: Colors.blue,
          ),
          const SizedBox(height: 8),
          if (iCanGiveIds.isEmpty)
            const _EmptyMessage('No tienes repetidas que el otro necesite')
          else
            _buildStampChips(context, iCanGiveIds, iCanGive, Colors.blue),
          const SizedBox(height: 16),

          // Lo que me puede dar
          _buildSectionHeader(
            context,
            icon: Icons.arrow_back,
            title: 'Te puede dar',
            subtitle: '${theyCanGiveIds.length} estampas',
            color: Colors.orange,
          ),
          const SizedBox(height: 8),
          if (theyCanGiveIds.isEmpty)
            const _EmptyMessage('El otro no tiene repetidas que tú necesites')
          else
            _buildStampChips(context, theyCanGiveIds, theyCanGive, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStat(context, 'Tú', '${result.myOwned}/${result.totalStamps}'),
                _buildStat(context, 'Otro', '${result.theirOwned}/${result.totalStamps}'),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStat(context, 'Te faltan', '${result.myMissing}',
                    color: Colors.red),
                _buildStat(context, 'Le faltan', '${result.theirMissing}',
                    color: Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(BuildContext context, String label, String value,
      {Color? color}) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            subtitle,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildStampChips(
    BuildContext context,
    List<int> ids,
    Map<int, int> countsMap,
    Color color,
  ) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: ids.map((id) {
        final count = countsMap[id] ?? 0;
        return Chip(
          label: Text(
            count > 1 ? '#$id ×$count' : '#$id',
            style: const TextStyle(fontSize: 12),
          ),
          backgroundColor: color.withOpacity(0.1),
          side: BorderSide(color: color.withOpacity(0.3)),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  final String text;
  const _EmptyMessage(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: TextStyle(color: Colors.grey[500])),
    );
  }
}
