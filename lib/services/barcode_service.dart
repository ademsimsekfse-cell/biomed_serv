import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeService {
  Future<String> scanBarcode(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const BarcodeScannerDialog(),
    );
    return result ?? '';
  }
}

class BarcodeScannerDialog extends StatefulWidget {
  const BarcodeScannerDialog({super.key});

  @override
  State<BarcodeScannerDialog> createState() => _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState extends State<BarcodeScannerDialog> {
  bool _isScanning = true;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: double.infinity,
        height: 400,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Barkod Tara',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(''),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isScanning
                  ? MobileScanner(
                      onDetect: (BarcodeCapture capture) {
                        final List<Barcode> barcodes = capture.barcodes;
                        if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                          setState(() => _isScanning = false);
                          Navigator.of(context).pop(barcodes.first.rawValue);
                        }
                      },
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(''),
              icon: const Icon(Icons.cancel),
              label: const Text('İptal'),
            ),
          ],
        ),
      ),
    );
  }
}
