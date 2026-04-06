import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/exchange_service.dart';
import '../services/config_service.dart';

/// Tab de Intercambio: muestra QR propio, escáner y resultado — todo inline.
class ExchangeTab extends StatefulWidget {
  final Map<int, int> ownedMap;
  final String qrData;

  const ExchangeTab({
    super.key,
    required this.ownedMap,
    required this.qrData,
  });

  @override
  State<ExchangeTab> createState() => _ExchangeTabState();
}

class _ExchangeTabState extends State<ExchangeTab> {
  ExchangeResult? _result;

  void _showResult(ExchangeResult result) {
    setState(() => _result = result);
  }

  void _clearResult() {
    setState(() => _result = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) {
      return _ExchangeResultBody(
        result: _result!,
        onBack: _clearResult,
      );
    }
    return _ExchangeQrBody(
      ownedMap: widget.ownedMap,
      qrData: widget.qrData,
      onResult: _showResult,
    );
  }
}

// ─── QR Panel ───────────────────────────────────────────────────────────────

class _ExchangeQrBody extends StatelessWidget {
  final Map<int, int> ownedMap;
  final String qrData;
  final void Function(ExchangeResult) onResult;

  const _ExchangeQrBody({
    required this.ownedMap,
    required this.qrData,
    required this.onResult,
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
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _simulate(totalStamps),
            icon: const Icon(Icons.science_outlined, size: 18),
            label: const Text('Simular escaneo (demo)'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              foregroundColor: Colors.grey[600],
              side: BorderSide(color: Colors.grey.shade400),
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

  Future<void> _openScanner(BuildContext context, int totalStamps) async {
    final result = await Navigator.of(context).push<ExchangeResult>(
      MaterialPageRoute(
        builder: (_) => ScannerScreen(
          myMap: ownedMap,
          totalStamps: totalStamps,
        ),
      ),
    );
    if (result != null) onResult(result);
  }

  void _simulate(int totalStamps) {
    final fakeMap = <int, int>{};
    for (var i = 2; i <= totalStamps; i += 2) {
      final repeats = (i % 10 == 0) ? 2 : (i % 6 == 0) ? 1 : 0;
      fakeMap[i] = repeats;
    }
    for (var i in [3, 7, 15, 31, 55, 77, 103, 201, 305, 450, 600, 750]) {
      if (i <= totalStamps) fakeMap[i] = 0;
    }

    final result = ExchangeService.compare(
      myMap: ownedMap,
      theirMap: fakeMap,
      totalStamps: totalStamps,
    );
    onResult(result);
  }
}

// ─── Scanner ────────────────────────────────────────────────────────────────

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

    Navigator.of(context).pop(result);
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

// ─── Result body (inline, sin Scaffold propio) ───────────────────────────────

class _ExchangeResultBody extends StatelessWidget {
  final ExchangeResult result;
  final VoidCallback onBack;

  const _ExchangeResultBody({required this.result, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final iCanGive = result.iCanGive;
    final theyCanGive = result.theyCanGive;
    final iCanGiveIds = iCanGive.keys.toList()..sort();
    final theyCanGiveIds = theyCanGive.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Botón volver arriba
        Row(
          children: [
            IconButton.outlined(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Volver',
            ),
            const SizedBox(width: 8),
            Text(
              'Resultado del intercambio',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 12),

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
        const SizedBox(height: 16),

        // Botón volver abajo
        OutlinedButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.qr_code),
          label: const Text('Nueva comparación'),
        ),
      ],
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
                _buildStat(context, 'Te faltan', '${result.myMissing}', color: Colors.red),
                _buildStat(context, 'Le faltan', '${result.theirMissing}', color: Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(BuildContext context, String label, String value, {Color? color}) {
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
      spacing: 4,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: ids.map((id) {
        final count = countsMap[id] ?? 0;
        return Container(
          width: 72,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$id',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: color.withOpacity(0.85),
                      ),
                    ),
                    Text(
                      count > 1 ? 'x$count' : '',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: color.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
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