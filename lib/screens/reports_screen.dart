import 'package:biomed_serv/services/database_service.dart';
import 'package:biomed_serv/services/report_export_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _isLoading = false;
  DateTime? _startDate;
  DateTime? _endDate;
  ReportExportService? _exportService;

  final List<Map<String, dynamic>> _reportTypes = [
    {
      'id': 'service',
      'title': 'Servis Formlari',
      'icon': Icons.build,
      'color': Colors.blue,
      'description': 'Servis kayitlarini tablo halinde al.',
    },
    {
      'id': 'maintenance',
      'title': 'Bakim Formlari',
      'icon': Icons.handyman,
      'color': Colors.orange,
      'description': 'Bakim kayitlarini tablo halinde al.',
    },
    {
      'id': 'stock',
      'title': 'Stok Raporu',
      'icon': Icons.inventory_2,
      'color': Colors.green,
      'description': 'Mevcut stok durumunu tek listede gor.',
    },
    {
      'id': 'devices',
      'title': 'Cihaz Listesi',
      'icon': Icons.devices,
      'color': Colors.purple,
      'description': 'Tum cihazlari tablo halinde al.',
    },
    {
      'id': 'expenses',
      'title': 'Masraf Raporu',
      'icon': Icons.receipt_long,
      'color': Colors.red,
      'description': 'Masraf kayitlarini ve raporlarini disa aktar.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  void _initializeService() {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    _exportService = ReportExportService(dbService);
  }

  @override
  Widget build(BuildContext context) {
      return Scaffold(
      appBar: AppBar(
        title: const Text('Raporlar'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroCard(),
            const SizedBox(height: 16),
            _buildDateFilterSection(),
            const SizedBox(height: 24),
            const Text(
              'Hazir Listeler',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._reportTypes.map(_buildReportCard),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilterSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tarih Araligi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Istersen raporu belli bir tarih araligina gore sinirlayabilirsin.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _selectDate(true),
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _startDate != null
                          ? DateFormat('dd.MM.yyyy').format(_startDate!)
                          : 'Baslangic',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.arrow_forward, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _selectDate(false),
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _endDate != null
                          ? DateFormat('dd.MM.yyyy').format(_endDate!)
                          : 'Bitis',
                    ),
                  ),
                ),
              ],
            ),
            if (_startDate != null || _endDate != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _startDate = null;
                    _endDate = null;
                  });
                },
                icon: const Icon(Icons.clear),
                label: const Text('Filtreyi Temizle'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assessment, color: Colors.white, size: 28),
              SizedBox(width: 10),
              Text(
                'Rapor Alma ve Paylasma',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'Buradan servis, bakim, cihaz, stok ve masraf kayitlarini Excel veya CSV olarak hazirlayabilirsin.',
            style: TextStyle(
              color: Colors.white70,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final color = report['color'] as Color;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(report['icon'] as IconData, color: color),
        ),
        title: Text(
          report['title'] as String,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(report['description'] as String),
        trailing: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : PopupMenuButton<String>(
                onSelected: (value) => _onExportSelected(
                  report['id'] as String,
                  value,
                ),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'excel',
                    child: Row(
                      children: [
                        Icon(Icons.table_chart, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Excel (.xlsx)'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'csv',
                    child: Row(
                      children: [
                        Icon(Icons.description, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('CSV (.csv)'),
                      ],
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'preview',
                    child: Row(
                      children: [
                        Icon(Icons.visibility, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Kisa Onizleme'),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _selectDate(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        if (isStart) {
          _startDate = date;
        } else {
          _endDate = date;
        }
      });
    }
  }

  Future<void> _onExportSelected(String reportType, String format) async {
    if (_exportService == null) return;

    if (format == 'preview') {
      _showPreview(reportType);
      return;
    }

    setState(() => _isLoading = true);
    try {
      late final String filePath;
      if (format == 'excel') {
        filePath = await _exportToExcel(reportType);
      } else {
        filePath = await _exportService!.exportToCsv(
          reportType: reportType,
          startDate: _startDate,
          endDate: _endDate,
        );
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
      _showExportSuccessDialog(filePath);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rapor olusturma hatasi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String> _exportToExcel(String reportType) async {
    switch (reportType) {
      case 'service':
        return _exportService!.exportServiceFormsToExcel(
          startDate: _startDate,
          endDate: _endDate,
        );
      case 'maintenance':
        return _exportService!.exportMaintenanceFormsToExcel(
          startDate: _startDate,
          endDate: _endDate,
        );
      case 'stock':
        return _exportService!.exportStockReportToExcel();
      case 'devices':
        return _exportService!.exportDevicesToExcel();
      case 'expenses':
        return _exportService!.exportExpensesToExcel();
      default:
        throw Exception('Bilinmeyen rapor tipi: $reportType');
    }
  }

  void _showPreview(String reportType) {
    final title = _reportTitle(reportType);
    final count = _previewCount(reportType);
    final rangeText = _selectedRangeText();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.visibility, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(child: Text('$title Onizleme')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _previewInfoRow('Kayit Sayisi', '$count'),
            const SizedBox(height: 8),
            _previewInfoRow('Tarih Araligi', rangeText),
            const SizedBox(height: 12),
            Text(
              'Bu onizleme, dosya olusturmadan once hangi verilerin alinacagini hizlica gormen icin hazirlandi.',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Kapat'),
          ),
          FilledButton.tonal(
            onPressed: () {
              Navigator.of(ctx).pop();
              _onExportSelected(reportType, 'csv');
            },
            child: const Text('CSV Olustur'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _onExportSelected(reportType, 'excel');
            },
            child: const Text('Excel Olustur'),
          ),
        ],
      ),
    );
  }

  Widget _previewInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }

  String _reportTitle(String reportType) {
    return (_reportTypes.firstWhere(
      (item) => item['id'] == reportType,
      orElse: () => const {'title': 'Rapor'},
    )['title']) as String;
  }

  int _previewCount(String reportType) {
    final db = context.read<DatabaseService>();
    switch (reportType) {
      case 'service':
        return db.serviceFormsBox.values
            .where((form) => _matchesDateRange(form.createdAt))
            .length;
      case 'maintenance':
        return db.maintenanceFormsBox.values
            .where((form) => _matchesDateRange(form.createdAt))
            .length;
      case 'stock':
        return db.stocksBox.length;
      case 'devices':
        return db.devicesBox.length;
      case 'expenses':
        return db.expensesBox.values
            .where((expense) => _matchesDateRange(expense.date))
            .length;
      default:
        return 0;
    }
  }

  bool _matchesDateRange(DateTime date) {
    final start = _startDate;
    final end = _endDate;
    if (start != null &&
        date.isBefore(DateTime(start.year, start.month, start.day))) {
      return false;
    }
    if (end != null) {
      final inclusiveEnd = DateTime(end.year, end.month, end.day, 23, 59, 59);
      if (date.isAfter(inclusiveEnd)) {
        return false;
      }
    }
    return true;
  }

  String _selectedRangeText() {
    if (_startDate == null && _endDate == null) {
      return 'Tum kayitlar';
    }
    final formatter = DateFormat('dd.MM.yyyy');
    final start = _startDate == null ? '-' : formatter.format(_startDate!);
    final end = _endDate == null ? '-' : formatter.format(_endDate!);
    return '$start - $end';
  }

  void _showExportSuccessDialog(String filePath) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Basarili'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Rapor dosyasi hazir.'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                filePath.split('/').last,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Kapat'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _openFile(filePath);
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Dosyayi Ac'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _shareFile(filePath);
            },
            icon: const Icon(Icons.share),
            label: const Text('Paylas'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFile(String path) async {
    try {
      await OpenFilex.open(path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dosya acilamadi: $e')),
      );
    }
  }

  Future<void> _shareFile(String path) async {
    try {
      await _exportService!.shareFile(path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Paylasma hatasi: $e')),
      );
    }
  }
}
