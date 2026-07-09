import 'package:biomed_serv/models/stock.dart';
import 'package:biomed_serv/providers/stock_provider.dart';
import 'package:biomed_serv/screens/column_mapping_screen.dart';
import 'package:biomed_serv/services/export_service.dart';
import 'package:biomed_serv/services/import_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

enum StockMenuAction { import, export, template }

class StockScreen extends StatelessWidget {
  const StockScreen({super.key});

  Future<void> _onMenuSelection(
    StockMenuAction action,
    BuildContext context,
  ) async {
    final stockProvider = Provider.of<StockProvider>(context, listen: false);
    final exportService = ExportService();
    final importService = ImportService();

    switch (action) {
      case StockMenuAction.import:
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['csv'],
        );
        if (result == null) return;
        if (!context.mounted) return;

        final filePath = result.files.single.path!;
        final headers = await importService.getHeaders(filePath);
        if (!context.mounted) return;
        if (headers.isEmpty) {
          _showErrorSnackbar(
            context,
            'CSV dosyasi bos veya baslik satiri bulunamadi.',
          );
          return;
        }

        final mapping = await Navigator.push<Map<String, String?>>(
          context,
          MaterialPageRoute(
            builder: (context) => ColumnMappingScreen(
              filePath: filePath,
              fileHeaders: headers,
              requiredFields: const [
                'name',
                'quantity',
                'barcode',
                'referenceNo',
                'criticalStockThreshold',
              ],
            ),
          ),
        );

        if (mapping == null) return;
        if (!context.mounted) return;

        final newStocks =
            await importService.importStocksFromCSV(filePath, mapping);
        if (!context.mounted) return;
        if (newStocks.isNotEmpty) {
          await stockProvider.addMultipleStocks(newStocks);
          if (!context.mounted) return;
          _showSuccessSnackbar(
            context,
            '${newStocks.length} adet stok basariyla ice aktarildi.',
          );
        } else {
          _showErrorSnackbar(
            context,
            'Ice aktarilacak gecerli veri bulunamadi. Eslestirmeleri kontrol edin.',
          );
        }
        break;

      case StockMenuAction.export:
        final path =
            await exportService.exportStocksToCSV(stockProvider.stocks);
        if (!context.mounted) return;
        if (path != null) {
          _showSuccessSnackbar(
            context,
            'Stok listesi basariyla disa aktarildi: $path',
          );
        } else {
          _showErrorSnackbar(
            context,
            'Dosya hazirlanamadi veya islem iptal edildi.',
          );
        }
        break;

      case StockMenuAction.template:
        final path = await exportService.exportStockTemplateCsv();
        if (!context.mounted) return;
        if (path != null) {
          _showSuccessSnackbar(
            context,
            'Bos stok sablonu hazirlandi: $path',
          );
        } else {
          _showErrorSnackbar(
            context,
            'Stok sablonu olusturulamadi veya kaydetme islemi iptal edildi.',
          );
        }
        break;
    }
  }

  void _showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok Yonetimi'),
        actions: [
          PopupMenuButton<StockMenuAction>(
            onSelected: (action) => _onMenuSelection(action, context),
            itemBuilder: (context) => const [
              PopupMenuItem<StockMenuAction>(
                value: StockMenuAction.import,
                child: ListTile(
                  leading: Icon(Icons.upload_file),
                  title: Text('Iceri Aktar (CSV)'),
                ),
              ),
              PopupMenuItem<StockMenuAction>(
                value: StockMenuAction.export,
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('Disari Aktar (CSV)'),
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem<StockMenuAction>(
                value: StockMenuAction.template,
                child: ListTile(
                  leading: Icon(Icons.description),
                  title: Text('Bos Sablon Indir'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<StockProvider>(
        builder: (context, provider, child) {
          if (provider.stocks.isEmpty) {
            return const Center(
              child: Text('Henuz stok eklenmemis.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: provider.stocks.length,
            itemBuilder: (context, index) {
              final stock = provider.stocks[index];
              final isLowStock = stock.quantity <= stock.criticalStockThreshold;
              return _buildStockCard(context, stock, isLowStock);
            },
          );
        },
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF9575CD), Color(0xFF5E35B1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5E35B1).withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _showAddStockDialog(context),
          tooltip: 'Yeni Stok Ekle',
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  void _showAddStockDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    final barcodeController = TextEditingController();
    final refNoController = TextEditingController();
    final thresholdController = TextEditingController(text: '10');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Yeni Stok Ekle'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Parca Adi'),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Bu alan zorunlu.'
                        : null,
                  ),
                  TextFormField(
                    controller: quantityController,
                    decoration: const InputDecoration(labelText: 'Miktar'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) => value == null || value.isEmpty
                        ? 'Bu alan zorunlu.'
                        : null,
                  ),
                  TextFormField(
                    controller: refNoController,
                    decoration: const InputDecoration(labelText: 'Referans No'),
                  ),
                  TextFormField(
                    controller: barcodeController,
                    decoration: const InputDecoration(labelText: 'Barkod'),
                  ),
                  TextFormField(
                    controller: thresholdController,
                    decoration: const InputDecoration(
                      labelText: 'Kritik Stok Esigi',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) => value == null || value.isEmpty
                        ? 'Bu alan zorunlu.'
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Iptal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final newStock = Stock(
                  name: nameController.text,
                  quantity: int.parse(quantityController.text),
                  referenceNo: refNoController.text.isEmpty
                      ? null
                      : refNoController.text,
                  barcode: barcodeController.text.isEmpty
                      ? null
                      : barcodeController.text,
                  criticalStockThreshold: int.parse(thresholdController.text),
                );
                context.read<StockProvider>().addStock(newStock);
                Navigator.of(ctx).pop();
              },
              child: const Text('Ekle'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStockCard(
    BuildContext context,
    Stock stock,
    bool isLowStock,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 1,
      color: isLowStock ? Colors.red.shade50 : null,
      child: InkWell(
        onTap: () => _showEditStockDialog(context, stock),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      isLowStock ? Colors.red.shade100 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isLowStock ? Icons.warning : Icons.inventory_2,
                  size: 22,
                  color:
                      isLowStock ? Colors.red.shade700 : Colors.orange.shade700,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            stock.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isLowStock
                                ? Colors.red.shade100
                                : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${stock.quantity}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isLowStock
                                  ? Colors.red.shade700
                                  : Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                        children: [
                          if (stock.referenceNo?.isNotEmpty == true)
                            TextSpan(text: 'Ref: ${stock.referenceNo}'),
                          if (stock.barcode?.isNotEmpty == true) ...[
                            if (stock.referenceNo?.isNotEmpty == true)
                              const TextSpan(text: ' • '),
                            TextSpan(text: 'Barkod: ${stock.barcode}'),
                          ],
                          if (isLowStock) ...[
                            const TextSpan(text: ' • '),
                            TextSpan(
                              text: 'Kritik Stok',
                              style: TextStyle(
                                color: Colors.red.shade600,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete, color: Colors.red.shade400, size: 20),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Stogu Sil'),
                      content: Text(
                        '"${stock.name}" kaydini silmek istediginizden emin misiniz?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Iptal'),
                        ),
                        TextButton(
                          onPressed: () {
                            context
                                .read<StockProvider>()
                                .deleteStock(stock.key);
                            Navigator.of(ctx).pop();
                          },
                          child: const Text('Sil'),
                        ),
                      ],
                    ),
                  );
                },
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: const EdgeInsets.all(4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditStockDialog(BuildContext context, Stock stock) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: stock.name);
    final quantityController =
        TextEditingController(text: stock.quantity.toString());
    final barcodeController = TextEditingController(text: stock.barcode ?? '');
    final refNoController =
        TextEditingController(text: stock.referenceNo ?? '');
    final thresholdController = TextEditingController(
      text: stock.criticalStockThreshold.toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Stok Duzenle'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Parca Adi'),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Bu alan zorunlu.'
                        : null,
                  ),
                  TextFormField(
                    controller: quantityController,
                    decoration: const InputDecoration(labelText: 'Miktar'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) => value == null || value.isEmpty
                        ? 'Bu alan zorunlu.'
                        : null,
                  ),
                  TextFormField(
                    controller: refNoController,
                    decoration: const InputDecoration(labelText: 'Referans No'),
                  ),
                  TextFormField(
                    controller: barcodeController,
                    decoration: const InputDecoration(labelText: 'Barkod'),
                  ),
                  TextFormField(
                    controller: thresholdController,
                    decoration: const InputDecoration(
                      labelText: 'Kritik Stok Esigi',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Iptal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                stock.name = nameController.text;
                stock.quantity = int.parse(quantityController.text);
                stock.barcode = barcodeController.text.isEmpty
                    ? null
                    : barcodeController.text;
                stock.referenceNo =
                    refNoController.text.isEmpty ? null : refNoController.text;
                stock.criticalStockThreshold =
                    int.tryParse(thresholdController.text) ?? 10;
                context.read<StockProvider>().updateStock(stock.key, stock);
                Navigator.of(ctx).pop();
              },
              child: const Text('Guncelle'),
            ),
          ],
        );
      },
    );
  }
}
