import 'package:biomed_serv/models/expense.dart';
import 'package:biomed_serv/models/expense_report.dart';
import 'package:biomed_serv/providers/expense_report_provider.dart';
import 'package:biomed_serv/screens/pdf_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Masraf Rapor Geçmişi Ekranı
/// Oluşturulan raporları listeler ve tahsilat yönetimi yapar
class ExpenseReportHistoryScreen extends StatelessWidget {
  const ExpenseReportHistoryScreen({super.key});

  String _collectionTypeLabel(CollectionType? type) {
    switch (type) {
      case CollectionType.eft:
        return 'EFT/Havale';
      case CollectionType.cash:
        return 'Nakit';
      case CollectionType.offset:
        return 'Mahsup';
      case null:
        return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    final currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapor Geçmişi'),
        actions: [
          // Özet göster
          IconButton(
            icon: const Icon(Icons.summarize),
            onPressed: () => _showSummaryDialog(context, currencyFormat),
            tooltip: 'Özet',
          ),
        ],
      ),
      body: Consumer<ExpenseReportProvider>(
        builder: (context, reportProvider, child) {
          final reports = reportProvider.reports;

          if (reports.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open_outlined,
                      size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz rapor bulunmuyor.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Masraf yönetiminden rapor oluşturun.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              return _buildReportCard(
                context,
                report,
                dateFormat,
                currencyFormat,
                reportProvider,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildReportCard(
    BuildContext context,
    ExpenseReport report,
    DateFormat dateFormat,
    NumberFormat currencyFormat,
    ExpenseReportProvider provider,
  ) {
    final expenses = provider.getReportExpenses(report);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: report.isCollected ? Colors.green.shade50 : null,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: report.isCollected
              ? Colors.green.shade100
              : Colors.orange.shade100,
          child: Icon(
            report.isCollected ? Icons.check_circle : Icons.pending,
            color: report.isCollected
                ? Colors.green.shade700
                : Colors.orange.shade700,
          ),
        ),
        title: Text(
          report.reportNumber,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              dateFormat.format(report.createdAt),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            Row(
              children: [
                Icon(
                  Icons.person,
                  size: 12,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Text(
                  report.technician.fullName,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.receipt,
                  size: 12,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Text(
                  '${expenses.length} masraf',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: report.isCollected
                ? Colors.green.shade100
                : Colors.orange.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            currencyFormat.format(report.totalAmount),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: report.isCollected
                  ? Colors.green.shade700
                  : Colors.orange.shade700,
            ),
          ),
        ),
        children: [
          // Masraf Detayları
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Raporlanan Masraflar:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...expenses.map((expense) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.arrow_right),
                      title: Text(
                        expense.description,
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        '${DateFormat('dd.MM.yyyy').format(expense.date)} - ${expense.relatedEntityName}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      trailing: Text(
                        currencyFormat.format(expense.amount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    )),
                const Divider(),
                // Toplam
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOPLAM:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      currencyFormat.format(report.totalAmount),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color:
                            report.isCollected ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),

                // Tahsilat Durumu
                if (report.isCollected) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Tahsil Edildi',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tahsilat Tipi: ${_collectionTypeLabel(report.collectionType)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade600,
                          ),
                        ),
                        if (report.collectionDate != null)
                          Text(
                            'Tahsilat Tarihi: ${DateFormat('dd.MM.yyyy').format(report.collectionDate!)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade600,
                            ),
                          ),
                        if (report.collectionNote != null &&
                            report.collectionNote!.isNotEmpty)
                          Text(
                            'Not: ${report.collectionNote}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],

                // Notlar
                if (report.notes != null && report.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Notlar: ${report.notes}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Butonlar
                Row(
                  children: [
                    if (report.pdfPath != null) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _openPdfPreview(context, report.pdfPath!),
                          icon: const Icon(Icons.visibility),
                          label: const Text('Önizle'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _openPdfPreview(context, report.pdfPath!),
                          icon: const Icon(Icons.share),
                          label: const Text('Önizle / Paylaş'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // Tahsilat Butonu (Tahsil edilmemişse)
                if (!report.isCollected) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _showCollectionDialog(context, report, provider),
                      icon: const Icon(Icons.payments),
                      label: const Text('Tahsilatı Kaydet'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ],

                // Sil Butonu
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _deleteReport(context, report, provider),
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text(
                    'Raporu Sil (Masrafları Geri Yükle)',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSummaryDialog(
    BuildContext context,
    NumberFormat currencyFormat,
  ) {
    final provider = Provider.of<ExpenseReportProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rapor Özeti'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryRow(
              'Toplam Rapor:',
              '${provider.totalReports} adet',
            ),
            const Divider(),
            _buildSummaryRow(
              'Tahsil Edilmemiş:',
              currencyFormat.format(provider.totalUncollectedAmount),
              valueColor: Colors.orange,
            ),
            _buildSummaryRow(
              'Tahsil Edilmiş:',
              currencyFormat.format(provider.totalCollectedAmount),
              valueColor: Colors.green,
            ),
            const Divider(),
            _buildSummaryRow(
              'GENEL TOPLAM:',
              currencyFormat.format(
                provider.totalUncollectedAmount + provider.totalCollectedAmount,
              ),
              isBold: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showCollectionDialog(
    BuildContext context,
    ExpenseReport report,
    ExpenseReportProvider provider,
  ) {
    final formKey = GlobalKey<FormState>();
    CollectionType selectedType = CollectionType.eft;
    final amountController = TextEditingController(
      text: report.remainingAmount.toStringAsFixed(2),
    );
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tahsilat Kaydet'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tutar: ${NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(report.totalAmount)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              StatefulBuilder(
                builder: (context, setState) {
                  Widget optionTile({
                    required CollectionType value,
                    required IconData icon,
                    required String label,
                  }) {
                    final selected = selectedType == value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.green.withValues(alpha: 0.08)
                            : Colors.grey.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? Colors.green : Colors.grey.shade300,
                        ),
                      ),
                      child: ListTile(
                        leading: Icon(
                          icon,
                          color: selected ? Colors.green : Colors.grey,
                        ),
                        title: Text(
                          label,
                          style: TextStyle(
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                        trailing: Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: selected ? Colors.green : Colors.grey,
                        ),
                        onTap: () => setState(() => selectedType = value),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      optionTile(
                        value: CollectionType.eft,
                        icon: Icons.account_balance,
                        label: 'EFT / Havale',
                      ),
                      optionTile(
                        value: CollectionType.cash,
                        icon: Icons.money,
                        label: 'Nakit',
                      ),
                      optionTile(
                        value: CollectionType.offset,
                        icon: Icons.swap_horiz,
                        label: 'Mahsup',
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Tahsil edilen miktar',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final amount =
                      double.tryParse((value ?? '').replaceAll(',', '.'));
                  if (amount == null || amount <= 0) {
                    return 'Geçerli bir miktar girin';
                  }
                  if (amount > report.remainingAmount + 0.01) {
                    return 'Kalan tutardan fazla olamaz';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Not (Opsiyonel)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate() && report.key != null) {
                final dialogNavigator = Navigator.of(ctx);
                final rootMessenger = ScaffoldMessenger.of(context);
                final amount =
                    double.parse(amountController.text.replaceAll(',', '.'));
                await provider.collectReport(
                  report.key!,
                  type: selectedType,
                  amount: amount,
                  note:
                      noteController.text.isEmpty ? null : noteController.text,
                );
                if (!ctx.mounted || !context.mounted) return;
                dialogNavigator.pop();
                rootMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Tahsilat kaydedildi!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _deleteReport(
    BuildContext context,
    ExpenseReport report,
    ExpenseReportProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Raporu Sil'),
        content: const Text(
          'Bu raporu silmek istediğinizden emin misiniz?\n\n'
          'Raporlanan masraflar "Bekliyor" durumuna geri dönecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (report.key != null) {
                final dialogNavigator = Navigator.of(ctx);
                final rootMessenger = ScaffoldMessenger.of(context);
                await provider.deleteReport(report.key!);
                if (!ctx.mounted || !context.mounted) return;
                dialogNavigator.pop();
                rootMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Rapor silindi ve masraflar geri yüklendi'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  Future<void> _openPdfPreview(BuildContext context, String pdfPath) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(
          filePath: pdfPath,
          title: 'Masraf Raporu Önizleme',
          shareText: 'Masraf Raporu',
        ),
      ),
    );
  }
}
