import 'package:biomed_serv/models/customer.dart';
import 'package:biomed_serv/models/device.dart';
import 'package:biomed_serv/models/expense.dart';
import 'package:biomed_serv/models/expense_report.dart';
import 'package:biomed_serv/providers/customer_provider.dart';
import 'package:biomed_serv/providers/device_provider.dart';
import 'package:biomed_serv/providers/expense_provider.dart';
import 'package:biomed_serv/providers/expense_report_provider.dart';
import 'package:biomed_serv/screens/expense_report_screen.dart';
import 'package:biomed_serv/screens/pdf_preview_screen.dart';
import 'package:biomed_serv/services/sound_service.dart';
import 'package:biomed_serv/utils/turkish_text_formatter.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Masraf Yönetim Ekranı
/// Masraf kayıtları, raporlama ve tahsilat yönetimi
class ExpenseManagementScreen extends StatefulWidget {
  const ExpenseManagementScreen({super.key});

  @override
  State<ExpenseManagementScreen> createState() =>
      _ExpenseManagementScreenState();
}

class _ExpenseManagementScreenState extends State<ExpenseManagementScreen>
    with SingleTickerProviderStateMixin {
  static const String _prefsBoxName = 'app_preferences';
  static const String _archivedReportsKey = 'archived_expense_reports';

  final Set<int> _selectedExpenseKeys = {};
  final Set<int> _selectedReportKeys = {};
  late final TabController _tabController;
  bool _isSelectionMode = false;
  bool _isReportSelectionMode = false;
  final Set<String> _archivedReportNumbers = {};
  bool _showArchivedReports = false;
  DateTimeRange? _collectedDateRange;

  // 🎯 AKILLI ÖNERİ LİSTELERİ
  List<String> _expenseDescriptions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != 1 &&
          (_isReportSelectionMode || _selectedReportKeys.isNotEmpty)) {
        setState(() {
          _isReportSelectionMode = false;
          _selectedReportKeys.clear();
        });
      }
    });
    // 🎯 Akıllı önerileri yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSuggestions();
      _loadArchivedReports();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 🎯 Mevcut masraflardan öneri listelerini oluştur
  void _loadSuggestions() {
    final expenseProvider =
        Provider.of<ExpenseProvider>(context, listen: false);
    final expenses = expenseProvider.expenses;

    setState(() {
      _expenseDescriptions = expenses
          .map((e) => e.description)
          .where((d) => d.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
    });
  }

  Future<void> _loadArchivedReports() async {
    final prefs = await Hive.openBox(_prefsBoxName);
    final raw =
        prefs.get(_archivedReportsKey) as List<dynamic>? ?? const <dynamic>[];
    if (!mounted) return;
    setState(() {
      _archivedReportNumbers
        ..clear()
        ..addAll(raw.map((item) => item.toString()));
    });
  }

  Future<void> _setReportArchived(
    ExpenseReport report,
    bool archived,
  ) async {
    setState(() {
      if (archived) {
        _archivedReportNumbers.add(report.reportNumber);
      } else {
        _archivedReportNumbers.remove(report.reportNumber);
      }
    });
    final prefs = await Hive.openBox(_prefsBoxName);
    await prefs.put(_archivedReportsKey, _archivedReportNumbers.toList());
  }

  // 🎯 Öneri gösteren TextField builder
  Widget _buildSuggestionField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required List<String> suggestions,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool required = false,
  }) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return suggestions.take(5); // İlk 5 öneri
        }
        return suggestions
            .where((s) =>
                s.toLowerCase().contains(textEditingValue.text.toLowerCase()))
            .take(10); // En fazla 10 öneri
      },
      onSelected: (String selection) {
        controller.text = normalizeDescriptionText(selection);
      },
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        // Controller senkronizasyonu
        if (textController.text != controller.text) {
          textController.text = controller.text;
        }

        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: const [TurkishUpperCaseTextFormatter()],
          decoration: InputDecoration(
            labelText: required ? '$label *' : label,
            prefixIcon: Icon(icon),
            border: const OutlineInputBorder(),
            suffixIcon: suggestions.isNotEmpty
                ? const Icon(Icons.lightbulb_outline,
                    color: Colors.amber, size: 20)
                : null,
          ),
          validator: validator,
          maxLines: maxLines,
          onChanged: (value) {
            controller.text = value;
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: MediaQuery.of(context).size.width - 80,
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    leading:
                        const Icon(Icons.history, color: Colors.grey, size: 18),
                    title: Text(option),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  bool _sameCustomer(Customer? a, Customer? b) {
    if (a == null || b == null) return false;
    if (a.key != null && b.key != null) return a.key == b.key;
    return a.name.trim().toLowerCase() == b.name.trim().toLowerCase() &&
        a.phone.trim() == b.phone.trim();
  }

  bool _sameDevice(Device? a, Device? b) {
    if (a == null || b == null) return false;
    if (a.key != null && b.key != null) return a.key == b.key;
    return a.serialNumber.trim().toLowerCase() ==
            b.serialNumber.trim().toLowerCase() &&
        a.name.trim().toLowerCase() == b.name.trim().toLowerCase();
  }

  Customer? _resolveCustomer(Customer? selected, List<Customer> customers) {
    if (selected == null) return null;
    for (final customer in customers) {
      if (_sameCustomer(selected, customer)) return customer;
    }
    return null;
  }

  Device? _resolveDevice(Device? selected, List<Device> devices) {
    if (selected == null) return null;
    for (final device in devices) {
      if (_sameDevice(selected, device)) return device;
    }
    return null;
  }

  List<Device> _devicesForExpense(
    List<Device> devices,
    Customer? selectedCustomer,
  ) {
    if (selectedCustomer == null) return devices;
    return devices.where((device) {
      final customer = device.customer;
      return customer is Customer && _sameCustomer(customer, selectedCustomer);
    }).toList();
  }

  Device? _findDeviceBySerial(List<Device> devices, String serial) {
    final normalized = serial.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final device in devices) {
      if (device.serialNumber.trim().toLowerCase() == normalized) {
        return device;
      }
    }
    return null;
  }

  List<Device> _serialLookupSuggestions(List<Device> devices, String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.length < 2) return const [];
    final matches = devices.where((device) {
      return device.serialNumber.trim().toLowerCase().contains(normalized) ||
          device.name.trim().toLowerCase().contains(normalized) ||
          device.model.trim().toLowerCase().contains(normalized);
    }).toList();
    matches.sort(
      (a, b) => a.serialNumber.length.compareTo(b.serialNumber.length),
    );
    return matches.take(4).toList();
  }

  Widget _buildExpenseSerialLookupCard({
    required TextEditingController controller,
    required List<Device> devices,
    required Device? selectedDevice,
    required Customer? selectedCustomer,
    required ValueChanged<String> onChanged,
    required ValueChanged<Device> onSelect,
    required VoidCallback onClear,
  }) {
    final query = controller.text.trim();
    final exactMatch = _findDeviceBySerial(devices, query);
    final suggestions = _serialLookupSuggestions(devices, query)
        .where((device) => !_sameDevice(device, exactMatch))
        .toList();
    final linkedCustomer = selectedCustomer ??
        (selectedDevice?.customer is Customer
            ? selectedDevice!.customer as Customer
            : null);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Seri No ile hizli bagla',
              helperText: 'Seri no yazinca kurum ve cihaz otomatik eslesir.',
              prefixIcon: const Icon(Icons.qr_code_2),
              border: const OutlineInputBorder(),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Temizle',
                      onPressed: onClear,
                      icon: const Icon(Icons.close),
                    ),
            ),
            onChanged: onChanged,
          ),
          if (selectedDevice != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${selectedDevice.name} - ${selectedDevice.serialNumber}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          linkedCustomer == null
                              ? 'Kurum atanmamis'
                              : linkedCustomer.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.blueGrey.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else if (query.isNotEmpty && exactMatch == null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.search_off, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Bu seri no ile kayitli cihaz bulunamadi.'),
                ),
              ],
            ),
          ],
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: suggestions
                  .map(
                    (device) => ActionChip(
                      avatar: const Icon(Icons.devices, size: 16),
                      label: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Text(
                          '${device.serialNumber} - ${device.name}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      onPressed: () => onSelect(device),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _collectionTypeLabel(CollectionType type) {
    switch (type) {
      case CollectionType.eft:
        return 'EFT Tahsil';
      case CollectionType.cash:
        return 'Nakit Tahsil';
      case CollectionType.offset:
        return 'Mahsup';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy');
    final currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    final reportProvider = context.watch<ExpenseReportProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Masraf Yönetimi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _tabController.animateTo(1),
            tooltip: 'Raporlanan Masraflar',
          ),
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: () {
                setState(() {
                  _isSelectionMode = false;
                  _selectedExpenseKeys.clear();
                });
              },
              tooltip: 'Seçimi İptal',
            ),
        ],
      ),
      body: Consumer2<ExpenseProvider, ExpenseReportProvider>(
        builder: (context, provider, reportProvider, child) {
          final pendingExpenses = provider.pendingExpenses;
          final reportedReports = reportProvider.uncollectedReports;
          final collectedReports = reportProvider.collectedReports;
          final visibleCollectedReports =
              _filterCollectedReports(collectedReports);

          return Column(
            children: [
              _buildSummaryCards(provider, currencyFormat),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _buildExpenseInsights(reportProvider, currencyFormat),
              ),
              Expanded(
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabs: [
                        Tab(
                          icon: const Icon(Icons.edit_note),
                          text: 'Bekleyen (${pendingExpenses.length})',
                        ),
                        Tab(
                          icon: const Icon(Icons.receipt_long),
                          text: 'Raporlanan (${reportedReports.length})',
                        ),
                        Tab(
                          icon: const Icon(Icons.verified),
                          text:
                              'Tahsil Edilen (${visibleCollectedReports.length})',
                        ),
                      ],
                      labelColor: Theme.of(context).primaryColor,
                      unselectedLabelColor: Colors.grey,
                      labelStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      unselectedLabelStyle: const TextStyle(fontSize: 12),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildExpenseList(
                            pendingExpenses,
                            dateFormat,
                            currencyFormat,
                            isSelectable: true,
                            emptyMessage: 'Raporlanmayı bekleyen masraf yok',
                          ),
                          _buildReportListTab(
                            context,
                            reportProvider,
                            reportedReports,
                            dateFormat,
                            currencyFormat,
                            emptyMessage: 'Raporlanmış masraf bulunmuyor',
                            selectable: true,
                          ),
                          _buildCollectedReportsTab(
                            context,
                            reportProvider,
                            visibleCollectedReports,
                            dateFormat,
                            currencyFormat,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      // Seçili masraflar için Rapor Oluştur butonu
      bottomNavigationBar:
          _isReportSelectionMode && _selectedReportKeys.isNotEmpty
              ? _buildReportSelectionBar(context, reportProvider)
              : _isSelectionMode && _selectedExpenseKeys.isNotEmpty
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_selectedExpenseKeys.length} masraf seçili',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _createReport(context),
                              icon: const Icon(Icons.assignment),
                              label: const Text('Rapor Oluştur'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Theme.of(context).primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : null,
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF66BB6A), Color(0xFF2E7D32)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _showAddExpenseDialog(context),
          tooltip: 'Yeni Masraf Ekle',
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildExpenseInsights(
    ExpenseReportProvider reportProvider,
    NumberFormat currencyFormat,
  ) {
    final waitingCount = reportProvider.reports
        .where(
            (report) => report.collectedAmount <= 0.01 && !report.isCollected)
        .length;
    final partialCount = reportProvider.reports
        .where((report) => report.collectedAmount > 0.01 && !report.isCollected)
        .length;
    final collectedCount = reportProvider.collectedReports.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long,
                size: 18,
                color: Colors.blueGrey.shade700,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Masraf rapor akışı',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${reportProvider.totalReports} rapor',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blueGrey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInsightChip(
                icon: Icons.schedule,
                label: 'Bekleyen $waitingCount',
                color: Colors.orange.shade700,
                background: Colors.orange.shade50,
              ),
              _buildInsightChip(
                icon: Icons.pie_chart_outline,
                label: 'Kısmi $partialCount',
                color: Colors.blue.shade700,
                background: Colors.blue.shade50,
              ),
              _buildInsightChip(
                icon: Icons.verified,
                label: 'Tamam $collectedCount',
                color: Colors.green.shade700,
                background: Colors.green.shade50,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Açık tahsilat: ${currencyFormat.format(reportProvider.totalUncollectedAmount)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blueGrey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightChip({
    required IconData icon,
    required String label,
    required Color color,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(
      ExpenseProvider provider, NumberFormat currencyFormat) {
    final cards = [
      _buildSummaryCard(
        'Bekleyen',
        provider.totalPendingAmount,
        Colors.orange,
        currencyFormat,
      ),
      _buildSummaryCard(
        'Tahsil Edilmemiş',
        provider.totalUnCollectedAmount,
        Colors.blue,
        currencyFormat,
      ),
      _buildSummaryCard(
        'Tahsil Edildi',
        provider.totalCollectedAmount,
        Colors.green,
        currencyFormat,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 520;
        if (!isCompact) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  Expanded(child: cards[i]),
                  if (i != cards.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          );
        }

        final itemWidth = (constraints.maxWidth - 40) / 2;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(width: itemWidth, child: cards[0]),
              SizedBox(width: itemWidth, child: cards[1]),
              SizedBox(width: constraints.maxWidth - 32, child: cards[2]),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(
    String title,
    double amount,
    Color color,
    NumberFormat currencyFormat,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.account_balance_wallet_outlined, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      currencyFormat.format(amount),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleReportSelection(int reportKey) {
    setState(() {
      if (_selectedReportKeys.contains(reportKey)) {
        _selectedReportKeys.remove(reportKey);
      } else {
        _selectedReportKeys.add(reportKey);
      }
      _isReportSelectionMode = _selectedReportKeys.isNotEmpty;
    });
  }

  Widget _buildReportSelectionBar(
    BuildContext context,
    ExpenseReportProvider provider,
  ) {
    final reports = provider.uncollectedReports
        .where(
          (report) =>
              report.key is int &&
              _selectedReportKeys.contains(report.key as int),
        )
        .toList();
    final total = reports.fold<double>(
      0,
      (sum, report) => sum + report.remainingAmount,
    );
    final currency = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

    return Material(
      color: const Color(0xFF173F35),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Seçimi kapat',
                    onPressed: () {
                      setState(() {
                        _selectedReportKeys.clear();
                        _isReportSelectionMode = false;
                      });
                    },
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${reports.length} rapor seçildi',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Kalan toplam: ${currency.format(total)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: reports.isEmpty
                          ? null
                          : () => _cancelSelectedReports(provider, reports),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                      ),
                      icon: const Icon(Icons.undo),
                      label: const Text('İptal Et'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: reports.isEmpty
                          ? null
                          : () => _showBulkReportCollectionSheet(
                                context,
                                provider,
                                reports,
                              ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF173F35),
                      ),
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Tahsil Et'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cancelSelectedReports(
    ExpenseReportProvider provider,
    List<ExpenseReport> reports,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Seçili raporları iptal et'),
            content: Text(
              '${reports.length} rapor iptal edilecek. İçindeki masraflar tekrar Bekleyen bölümüne taşınacak.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Raporları İptal Et'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    for (final report in reports) {
      final key = report.key;
      if (key is int) await provider.deleteReport(key);
    }
    if (!mounted) return;
    setState(() {
      _selectedReportKeys.clear();
      _isReportSelectionMode = false;
    });
    _tabController.animateTo(0);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${reports.length} rapor iptal edildi; masraflar Bekleyen bölümüne alındı.',
        ),
        backgroundColor: Colors.orange.shade800,
      ),
    );
  }

  void _showBulkReportCollectionSheet(
    BuildContext context,
    ExpenseReportProvider provider,
    List<ExpenseReport> reports,
  ) {
    CollectionType selectedType = CollectionType.eft;
    final noteController = TextEditingController();
    var confirmed = false;
    final currency = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    final total = reports.fold<double>(
      0,
      (sum, report) => sum + report.remainingAmount,
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  20 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Toplu Tahsilat',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${reports.length} raporun kalan tutarı kapatılacak.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              const Color(0xFF2E7D32).withValues(alpha: 0.22),
                        ),
                      ),
                      child: Text(
                        currency.format(total),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<CollectionType>(
                      segments: const [
                        ButtonSegment(
                          value: CollectionType.eft,
                          icon: Icon(Icons.account_balance_outlined),
                          label: Text('EFT'),
                        ),
                        ButtonSegment(
                          value: CollectionType.cash,
                          icon: Icon(Icons.payments_outlined),
                          label: Text('Nakit'),
                        ),
                        ButtonSegment(
                          value: CollectionType.offset,
                          icon: Icon(Icons.swap_horiz),
                          label: Text('Mahsup'),
                        ),
                      ],
                      selected: {selectedType},
                      onSelectionChanged: (selection) {
                        setSheetState(() => selectedType = selection.first);
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: noteController,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: const [
                        TurkishUpperCaseTextFormatter(),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Tahsilat notu',
                        prefixIcon: Icon(Icons.notes_outlined),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: confirmed,
                      onChanged: (value) {
                        setSheetState(() => confirmed = value ?? false);
                      },
                      title: const Text(
                        'Seçili raporların kalan tutarlarını kapat',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text(
                        'Bu işlem raporları Tahsil Edilen bölümüne taşır.',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: !confirmed
                            ? null
                            : () async {
                                for (final report in reports) {
                                  final key = report.key;
                                  if (key is! int ||
                                      report.remainingAmount <= 0.01) {
                                    continue;
                                  }
                                  await provider.collectReport(
                                    key,
                                    type: selectedType,
                                    amount: report.remainingAmount,
                                    note: noteController.text.trim().isEmpty
                                        ? null
                                        : normalizeDescriptionText(
                                            noteController.text,
                                          ),
                                  );
                                }
                                await SoundService().playSaveSuccess();
                                if (!mounted) return;
                                setState(() {
                                  _selectedReportKeys.clear();
                                  _isReportSelectionMode = false;
                                });
                                if (sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                                _tabController.animateTo(2);
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${reports.length} rapor tahsil edildi.',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              },
                        icon: const Icon(Icons.verified_outlined),
                        label: const Text('Tahsilatı Tamamla'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(noteController.dispose);
  }

  List<ExpenseReport> _filterCollectedReports(List<ExpenseReport> reports) {
    final rangeStart = _collectedDateRange?.start;
    final rangeEnd = _collectedDateRange == null
        ? null
        : DateTime(
            _collectedDateRange!.end.year,
            _collectedDateRange!.end.month,
            _collectedDateRange!.end.day,
            23,
            59,
            59,
            999,
          );

    return reports.where((report) {
      final archived = _archivedReportNumbers.contains(report.reportNumber);
      if (_showArchivedReports != archived) return false;
      final date = report.collectionDate ?? report.createdAt;
      if (rangeStart != null && date.isBefore(rangeStart)) return false;
      if (rangeEnd != null && date.isAfter(rangeEnd)) return false;
      return true;
    }).toList();
  }

  Future<void> _pickCollectedDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _collectedDateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
      helpText: 'Tahsilat tarih aralığı',
      saveText: 'Uygula',
    );
    if (picked != null && mounted) {
      setState(() => _collectedDateRange = picked);
    }
  }

  Widget _buildCollectedReportsTab(
    BuildContext context,
    ExpenseReportProvider provider,
    List<ExpenseReport> reports,
    DateFormat dateFormat,
    NumberFormat currencyFormat,
  ) {
    final dateLabel = _collectedDateRange == null
        ? 'Tarih'
        : '${dateFormat.format(_collectedDateRange!.start)} - '
            '${dateFormat.format(_collectedDateRange!.end)}';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickCollectedDateRange,
                  icon: const Icon(Icons.date_range_outlined, size: 18),
                  label: Text(
                    dateLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                selected: _showArchivedReports,
                avatar: Icon(
                  _showArchivedReports
                      ? Icons.inventory_2
                      : Icons.inventory_2_outlined,
                  size: 17,
                ),
                label: const Text('Arşiv'),
                onSelected: (value) {
                  setState(() => _showArchivedReports = value);
                },
              ),
              if (_collectedDateRange != null)
                IconButton(
                  tooltip: 'Tarihi temizle',
                  onPressed: () => setState(() => _collectedDateRange = null),
                  icon: const Icon(Icons.filter_alt_off_outlined),
                ),
            ],
          ),
        ),
        Expanded(
          child: reports.isEmpty
              ? Center(
                  child: Text(
                    _showArchivedReports
                        ? 'Arşivlenmiş rapor bulunmuyor.'
                        : 'Bu aralıkta tahsil edilmiş rapor bulunmuyor.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  itemCount: reports.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) =>
                      _buildCompactCollectedReportRow(
                    reports[index],
                    provider,
                    dateFormat,
                    currencyFormat,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCompactCollectedReportRow(
    ExpenseReport report,
    ExpenseReportProvider provider,
    DateFormat dateFormat,
    NumberFormat currencyFormat,
  ) {
    final archived = _archivedReportNumbers.contains(report.reportNumber);
    final collectionDate = report.collectionDate ?? report.createdAt;
    return Material(
      color: archived ? Colors.blueGrey.shade50 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(7),
        side: BorderSide(color: Colors.blueGrey.shade100),
      ),
      child: ListTile(
        dense: true,
        minVerticalPadding: 5,
        contentPadding: const EdgeInsets.only(left: 10, right: 2),
        leading: const Icon(
          Icons.verified_outlined,
          size: 22,
          color: Color(0xFF2E7D32),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                report.reportNumber,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              currencyFormat.format(report.totalAmount),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1B5E20),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${dateFormat.format(collectionDate)} • '
          '${report.technician.fullName} • '
          '${provider.getReportExpenses(report).length} kalem',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
        ),
        onTap: () => _showCollectedReportDetails(
          report,
          provider,
          currencyFormat,
        ),
        trailing: PopupMenuButton<String>(
          tooltip: 'İşlemler',
          onSelected: (value) {
            if (value == 'preview' &&
                report.pdfPath?.trim().isNotEmpty == true) {
              _openReportPdfPreview(context, report.pdfPath!);
            } else if (value == 'archive') {
              _setReportArchived(report, !archived);
            }
          },
          itemBuilder: (context) => [
            if (report.pdfPath?.trim().isNotEmpty == true)
              const PopupMenuItem(
                value: 'preview',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.visibility_outlined),
                  title: Text('Önizle'),
                ),
              ),
            PopupMenuItem(
              value: 'archive',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  archived ? Icons.unarchive_outlined : Icons.archive_outlined,
                ),
                title: Text(archived ? 'Arşivden Çıkar' : 'Arşivle'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCollectedReportDetails(
    ExpenseReport report,
    ExpenseReportProvider provider,
    NumberFormat currencyFormat,
  ) {
    final expenses = provider.getReportExpenses(report);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                report.reportNumber,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              ...expenses.map(
                (expense) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(expense.description),
                  subtitle: Text(expense.relatedEntityName),
                  trailing: Text(
                    currencyFormat.format(expense.amount),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const Divider(),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Toplam ${currencyFormat.format(report.totalAmount)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportListTab(
    BuildContext context,
    ExpenseReportProvider provider,
    List<ExpenseReport> reports,
    DateFormat dateFormat,
    NumberFormat currencyFormat, {
    required String emptyMessage,
    required bool selectable,
  }) {
    if (reports.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.folder_open_outlined,
                size: 72,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 14),
              Text(
                emptyMessage,
                style: TextStyle(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: reports.length,
      itemBuilder: (context, index) => _buildReportHistoryCard(
        context,
        reports[index],
        provider,
        dateFormat,
        currencyFormat,
        selectable: selectable,
      ),
    );
  }

  String _reportStatusLabel(ExpenseReport report) {
    if (report.isCollected) return 'Tahsil Edildi';
    if (report.collectedAmount > 0.01) return 'Kısmi Tahsil';
    return 'Tahsil Bekliyor';
  }

  IconData _reportStatusIcon(ExpenseReport report) {
    if (report.isCollected) return Icons.verified;
    if (report.collectedAmount > 0.01) return Icons.pie_chart_outline;
    return Icons.schedule;
  }

  Color _reportAccent(ExpenseReport report) {
    if (report.isCollected) return Colors.green.shade700;
    if (report.collectedAmount > 0.01) return Colors.blue.shade700;
    return Colors.orange.shade700;
  }

  Color _reportBackground(ExpenseReport report) {
    if (report.isCollected) return Colors.green.shade50;
    if (report.collectedAmount > 0.01) return Colors.blue.shade50;
    return Colors.orange.shade50;
  }

  Widget _buildReportHistoryCard(
    BuildContext context,
    ExpenseReport report,
    ExpenseReportProvider provider,
    DateFormat dateFormat,
    NumberFormat currencyFormat, {
    required bool selectable,
  }) {
    final expenses = provider.getReportExpenses(report);
    final accent = _reportAccent(report);
    final background = _reportBackground(report);
    final reportKey = report.key is int ? report.key as int : null;
    final isSelected =
        reportKey != null && _selectedReportKeys.contains(reportKey);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: selectable && reportKey != null
          ? () => _toggleReportSelection(reportKey)
          : null,
      onTap: _isReportSelectionMode && selectable && reportKey != null
          ? () => _toggleReportSelection(reportKey)
          : null,
      child: AbsorbPointer(
        absorbing: _isReportSelectionMode && selectable,
        child: Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: isSelected ? const Color(0xFFE8F5E9) : background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isSelected
                  ? const Color(0xFF2E7D32)
                  : accent.withValues(alpha: 0.14),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            leading: isSelected || (_isReportSelectionMode && selectable)
                ? CircleAvatar(
                    backgroundColor:
                        isSelected ? const Color(0xFF2E7D32) : Colors.white,
                    child: Icon(
                      isSelected ? Icons.check : Icons.circle_outlined,
                      color: isSelected ? Colors.white : Colors.grey.shade500,
                    ),
                  )
                : CircleAvatar(
                    backgroundColor: accent.withValues(alpha: 0.12),
                    child: Icon(_reportStatusIcon(report), color: accent),
                  ),
            title: Text(
              report.reportNumber,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateFormat.format(report.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person,
                              size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            report.technician.fullName,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: accent.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          _reportStatusLabel(report),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (selectable && reportKey != null) ...[
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        FilterChip(
                          selected: isSelected,
                          showCheckmark: true,
                          visualDensity: VisualDensity.compact,
                          label: Text(isSelected ? 'Seçildi' : 'Seç'),
                          onSelected: (_) => _toggleReportSelection(reportKey),
                        ),
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          onPressed: () => _showReportCollectionDialog(
                            context,
                            report,
                            provider,
                          ),
                          icon: const Icon(Icons.payments_outlined, size: 17),
                          label: Text(
                            report.collectedAmount > 0.01
                                ? 'Kalanı Tahsil Et'
                                : 'Tahsil Et',
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onPressed: () => _deleteExpenseReport(
                            context,
                            report,
                            provider,
                          ),
                          icon: const Icon(Icons.undo, size: 17),
                          label: const Text('İptal Et'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            trailing: Text(
              currencyFormat.format(report.totalAmount),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: accent,
              ),
            ),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildReportStatPill(
                          label: 'Masraf',
                          value: '${expenses.length}',
                        ),
                        _buildReportStatPill(
                          label: 'Tahsil',
                          value: currencyFormat.format(report.collectedAmount),
                        ),
                        _buildReportStatPill(
                          label: 'Kalan',
                          value: currencyFormat.format(report.remainingAmount),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Rapor kalemleri',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ...expenses.map(
                      (expense) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              expense.isCollected
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              size: 18,
                              color: expense.isCollected
                                  ? Colors.green.shade700
                                  : Colors.grey.shade500,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    expense.description,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${DateFormat('dd.MM.yyyy').format(expense.date)} • ${expense.relatedEntityName}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              currencyFormat.format(expense.amount),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (report.collectionType != null ||
                        report.collectionDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Son tahsilat: ${report.collectionType != null ? _collectionTypeLabel(report.collectionType!) : '-'}'
                          '${report.collectionDate != null ? ' • ${DateFormat('dd.MM.yyyy').format(report.collectionDate!)}' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    if (report.collectionNote != null &&
                        report.collectionNote!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Tahsilat notu: ${report.collectionNote}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    if (report.notes != null && report.notes!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Rapor notu: ${report.notes}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (report.pdfPath != null &&
                            report.pdfPath!.isNotEmpty)
                          OutlinedButton.icon(
                            onPressed: () =>
                                _openReportPdfPreview(context, report.pdfPath!),
                            icon: const Icon(Icons.visibility),
                            label: const Text('Önizle'),
                          ),
                        if (!report.isCollected && report.key is int)
                          ElevatedButton.icon(
                            onPressed: () => _showReportCollectionDialog(
                              context,
                              report,
                              provider,
                            ),
                            icon: const Icon(Icons.payments),
                            label: Text(
                              report.collectedAmount > 0.01
                                  ? 'Kalanı Tahsil Et'
                                  : 'Tahsilat Gir',
                            ),
                          ),
                        if (report.key is int)
                          TextButton.icon(
                            onPressed: () => _deleteExpenseReport(
                              context,
                              report,
                              provider,
                            ),
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            label: const Text(
                              'Raporu Geri Al',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportStatPill({
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportCollectionDialog(
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
        title: const Text('Rapor Tahsilatı'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Kalan tutar: ${NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(report.remainingAmount)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              StatefulBuilder(
                builder: (context, setInnerState) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildCollectionTypeChip(
                      type: CollectionType.eft,
                      selectedType: selectedType,
                      icon: Icons.account_balance,
                      label: 'EFT/Havale',
                      color: const Color(0xFF1565C0),
                      selectedColor: const Color(0xFFE3F2FD),
                      onSelected: () => setInnerState(
                          () => selectedType = CollectionType.eft),
                    ),
                    _buildCollectionTypeChip(
                      type: CollectionType.cash,
                      selectedType: selectedType,
                      icon: Icons.money,
                      label: 'Nakit',
                      color: const Color(0xFF2E7D32),
                      selectedColor: const Color(0xFFE8F5E9),
                      onSelected: () => setInnerState(
                        () => selectedType = CollectionType.cash,
                      ),
                    ),
                    _buildCollectionTypeChip(
                      type: CollectionType.offset,
                      selectedType: selectedType,
                      icon: Icons.swap_horiz,
                      label: 'Mahsup',
                      color: const Color(0xFF6A1B9A),
                      selectedColor: const Color(0xFFF3E5F5),
                      onSelected: () => setInnerState(
                        () => selectedType = CollectionType.offset,
                      ),
                    ),
                  ],
                ),
              ),
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
                    return 'Kalan tutarı aşamaz';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: const [TurkishUpperCaseTextFormatter()],
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Not',
                  border: OutlineInputBorder(),
                ),
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
              if (!formKey.currentState!.validate()) return;
              if (report.key is! int) return;

              final amount =
                  double.parse(amountController.text.replaceAll(',', '.'));
              await provider.collectReport(
                report.key as int,
                type: selectedType,
                amount: amount,
                note: noteController.text.trim().isEmpty
                    ? null
                    : normalizeDescriptionText(noteController.text),
              );

              if (ctx.mounted) {
                Navigator.of(ctx).pop();
              }

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Rapor tahsilatı kaydedildi'),
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

  Future<void> _deleteExpenseReport(
    BuildContext context,
    ExpenseReport report,
    ExpenseReportProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rapor geri alınacak'),
        content: const Text(
          'Bu rapor silinirse bağlı masraflar tekrar bekleyen duruma döner.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Raporu Geri Al'),
          ),
        ],
      ),
    );

    if (confirmed != true || report.key is! int) return;

    await provider.deleteReport(report.key as int);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rapor geri alındı, masraflar tekrar açıldı'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _openReportPdfPreview(
    BuildContext context,
    String pdfPath,
  ) async {
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

  Widget _buildExpenseList(
    List<Expense> expenses,
    DateFormat dateFormat,
    NumberFormat currencyFormat, {
    required bool isSelectable,
    String? emptyMessage,
    Function(Expense)? onItemTap,
  }) {
    if (expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              emptyMessage ?? 'Henüz masraf kaydı bulunmuyor.',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: expenses.length,
      itemBuilder: (context, index) {
        final expense = expenses[index];
        final isSelected = _selectedExpenseKeys.contains(expense.key);

        return _buildExpenseCard(
          context,
          expense,
          isSelected,
          isSelectable,
          dateFormat,
          currencyFormat,
          onTap: onItemTap != null ? () => onItemTap(expense) : null,
        );
      },
    );
  }

  /// Masraf Kartı - Kompakt
  Widget _buildExpenseCard(
    BuildContext context,
    Expense expense,
    bool isSelected,
    bool isSelectable,
    DateFormat dateFormat,
    NumberFormat currencyFormat, {
    VoidCallback? onTap,
  }) {
    void toggleSelection() {
      if (expense.key is! int) return;
      setState(() {
        final key = expense.key as int;
        if (_selectedExpenseKeys.contains(key)) {
          _selectedExpenseKeys.remove(key);
        } else {
          _selectedExpenseKeys.add(key);
        }
        _isSelectionMode = _selectedExpenseKeys.isNotEmpty;
      });
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      color: isSelected ? Colors.blue.shade50 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(7),
        side: BorderSide(
          color: isSelected ? Colors.blue.shade400 : Colors.blueGrey.shade100,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            onTap: onTap ??
                (isSelectable
                    ? toggleSelection
                    : () {
                        if (expense.isReported) {
                          _showCollectionOptions(context, expense);
                        }
                      }),
            onLongPress: expense.isPending
                ? () => _showEditExpenseDialog(context, expense)
                : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 10, 7),
              child: Row(
                children: [
                  if (isSelectable)
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) => toggleSelection(),
                      visualDensity: VisualDensity.compact,
                    )
                  else
                    Icon(
                      expense.isCollected
                          ? Icons.check_circle
                          : expense.isReported
                              ? Icons.description
                              : Icons.pending,
                      color: Color(expense.statusColor),
                      size: 24,
                    ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense.description,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            dateFormat.format(expense.date),
                            if (expense.customer != null ||
                                expense.device != null)
                              expense.relatedEntityName,
                          ].join(' • '),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    currencyFormat.format(expense.amount),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Color(expense.statusColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expense.isPending) ...[
            Divider(height: 1, color: Colors.blueGrey.shade100),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: toggleSelection,
                      icon: Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.playlist_add_check_circle_outlined,
                        size: 17,
                      ),
                      label:
                          Text(isSelected ? 'Rapora Eklendi' : 'Rapora Ekle'),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showEditExpenseDialog(context, expense),
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    label: const Text('Düzenle'),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                    ),
                    onPressed: () => _deleteExpense(context, expense),
                    icon: const Icon(Icons.delete_outline, size: 17),
                    label: const Text('Sil'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Masraf silme işlemi
  Future<void> _deleteExpense(BuildContext context, Expense expense) async {
    // Onay dialogu göster
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Text('Masraf Silinecek'),
          ],
        ),
        content: Text(
          '"${expense.description}" masrafı silinecek.\n\n'
          'Tutar: ${NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(expense.amount)}\n\n'
          'Bu işlem geri alınamaz!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('İptal'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete, color: Colors.white),
            label: const Text('Sil'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final expenseProvider =
            Provider.of<ExpenseProvider>(context, listen: false);
        await expenseProvider.deleteExpense(expense.key);

        // 🔊 Başarılı sesi
        await SoundService().playSuccess();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🗑️ ${expense.description} silindi'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        // 🔊 Hata sesi
        await SoundService().playError();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Silme hatası: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showAddExpenseDialog(BuildContext context) {
    _showExpenseFormDialog(context, null);
  }

  void _showEditExpenseDialog(BuildContext context, Expense expense) {
    _showExpenseFormDialog(context, expense);
  }

  void _showExpenseFormDialog(BuildContext context, Expense? expense) {
    final isEditing = expense != null;
    final formKey = GlobalKey<FormState>();
    final dateController = TextEditingController(
      text: isEditing
          ? DateFormat('dd.MM.yyyy').format(expense.date)
          : DateFormat('dd.MM.yyyy').format(DateTime.now()),
    );
    final descriptionController = TextEditingController(
      text: isEditing ? expense.description : '',
    );
    final amountController = TextEditingController(
      text: isEditing ? expense.amount.toString() : '',
    );

    Customer? selectedCustomer = expense?.customer;
    Device? selectedDevice = expense?.device;
    final serialLookupController = TextEditingController(
      text: selectedDevice?.serialNumber ?? '',
    );

    void selectDevice(Device? device, {bool updateSerialField = true}) {
      selectedDevice = device;
      final deviceCustomer = device?.customer;
      if (deviceCustomer is Customer) {
        selectedCustomer = deviceCustomer;
      }
      if (updateSerialField) {
        serialLookupController.text = device?.serialNumber ?? '';
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Masrafı Düzenle' : 'Yeni Masraf Ekle'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tarih
                  TextFormField(
                    controller: dateController,
                    decoration: const InputDecoration(
                      labelText: 'Tarih (GG.AA.YYYY)',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v!.isEmpty ? 'Tarih zorunludur' : null,
                  ),
                  const SizedBox(height: 12),

                  // 🎯 AÇIKLAMA - Akıllı Öneri
                  _buildSuggestionField(
                    controller: descriptionController,
                    label: 'Açıklama',
                    icon: Icons.description,
                    suggestions: _expenseDescriptions,
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Açıklama zorunludur' : null,
                    maxLines: 2,
                    required: true,
                  ),
                  const SizedBox(height: 12),

                  // Tutar
                  TextFormField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Tutar (₺) *',
                      prefixIcon: Icon(Icons.attach_money),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v!.isEmpty) return 'Tutar zorunludur';
                      if (double.tryParse(v.replaceAll(',', '.')) == null) {
                        return 'Geçerli bir tutar girin';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  Consumer<DeviceProvider>(
                    builder: (context, deviceProvider, child) {
                      return _buildExpenseSerialLookupCard(
                        controller: serialLookupController,
                        devices: deviceProvider.devices,
                        selectedDevice: selectedDevice,
                        selectedCustomer: selectedCustomer,
                        onChanged: (value) {
                          final match = _findDeviceBySerial(
                              deviceProvider.devices, value);
                          if (match == null ||
                              _sameDevice(match, selectedDevice)) {
                            return;
                          }
                          setDialogState(() {
                            selectDevice(match, updateSerialField: false);
                          });
                        },
                        onSelect: (device) {
                          setDialogState(() {
                            selectDevice(device);
                          });
                        },
                        onClear: () {
                          setDialogState(() {
                            serialLookupController.clear();
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Kurum Seçimi (Opsiyonel)
                  Consumer<CustomerProvider>(
                    builder: (context, customerProvider, child) {
                      final resolvedCustomer = _resolveCustomer(
                        selectedCustomer,
                        customerProvider.customers,
                      );
                      selectedCustomer = resolvedCustomer;

                      return DropdownButtonFormField<Customer>(
                        initialValue: resolvedCustomer,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'İlişkili Kurum (Opsiyonel)',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<Customer>(
                            value: null,
                            child: Text('Kurum Seç...'),
                          ),
                          ...customerProvider.customers.map((customer) {
                            return DropdownMenuItem<Customer>(
                              value: customer,
                              child: Text(
                                customer.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            selectedCustomer = value;
                            selectedDevice = null;
                            serialLookupController.clear();
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Cihaz Seçimi (Opsiyonel)
                  Consumer<DeviceProvider>(
                    builder: (context, deviceProvider, child) {
                      final availableDevices = _devicesForExpense(
                        deviceProvider.devices,
                        selectedCustomer,
                      );
                      final resolvedDevice =
                          _resolveDevice(selectedDevice, availableDevices);
                      selectedDevice = resolvedDevice;

                      return DropdownButtonFormField<Device>(
                        initialValue: resolvedDevice,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'İlişkili Cihaz (Opsiyonel)',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<Device>(
                            value: null,
                            child: Text('Cihaz Seç...'),
                          ),
                          ...availableDevices.map((device) {
                            return DropdownMenuItem<Device>(
                              value: device,
                              child: Text(
                                '${device.name} • ${device.serialNumber}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            selectDevice(value);
                          });
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (isEditing)
              TextButton.icon(
                onPressed: () async {
                  final expenseProvider =
                      Provider.of<ExpenseProvider>(context, listen: false);
                  final dialogNavigator = Navigator.of(ctx);
                  final rootMessenger = ScaffoldMessenger.of(context);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Masrafı Sil'),
                      content: const Text(
                          'Bu masraf kaydını silmek istediğinizden emin misiniz?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('İptal'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red),
                          child: const Text('Sil'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true && expense.key != null) {
                    await expenseProvider.deleteExpense(expense.key!);
                    if (!ctx.mounted || !mounted) return;
                    dialogNavigator.pop();
                    rootMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Masraf silindi'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text('Sil', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final provider =
                      Provider.of<ExpenseProvider>(context, listen: false);
                  final dialogNavigator = Navigator.of(ctx);
                  final rootMessenger = ScaffoldMessenger.of(context);
                  final dialogMessenger = ScaffoldMessenger.of(ctx);
                  try {
                    // 🎯 Tarih parse işlemi - güvenli
                    final dateParts = dateController.text.trim().split('.');
                    if (dateParts.length != 3) {
                      throw FormatException('Geçersiz tarih formatı');
                    }

                    final day = int.tryParse(dateParts[0]);
                    final month = int.tryParse(dateParts[1]);
                    final year = int.tryParse(dateParts[2]);

                    if (day == null || month == null || year == null) {
                      throw FormatException('Geçersiz tarih değerleri');
                    }

                    if (day < 1 ||
                        day > 31 ||
                        month < 1 ||
                        month > 12 ||
                        year < 2000) {
                      throw FormatException(
                          'Tarih değerleri geçersiz aralıkta');
                    }

                    final date = DateTime(year, month, day);

                    // 🎯 Tutar parse işlemi - güvenli
                    final amountText =
                        amountController.text.trim().replaceAll(',', '.');
                    final amount = double.tryParse(amountText);
                    if (amount == null || amount <= 0) {
                      throw FormatException('Geçersiz tutar');
                    }

                    final newExpense = Expense(
                      date: date,
                      description:
                          normalizeDescriptionText(descriptionController.text),
                      amount: amount,
                      customer: selectedCustomer,
                      device: selectedDevice,
                    );

                    if (isEditing && expense.key != null) {
                      await provider.updateExpense(expense.key, newExpense);
                      // 🔊 Başarı sesi
                      await SoundService().playSaveSuccess();
                      if (mounted) {
                        rootMessenger.showSnackBar(
                          const SnackBar(
                            content: Text('✅ Masraf güncellendi'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } else {
                      await provider.addExpense(newExpense);
                      // 🔊 Başarı sesi
                      await SoundService().playSaveSuccess();
                      if (mounted) {
                        rootMessenger.showSnackBar(
                          const SnackBar(
                            content: Text('✅ Masraf eklendi'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    }

                    if (ctx.mounted) {
                      dialogNavigator.pop();
                    }
                  } catch (e) {
                    // 🔊 Hata sesi
                    await SoundService().playError();
                    debugPrint('🚨 Masraf kaydetme hatası: $e');
                    if (ctx.mounted) {
                      dialogMessenger.showSnackBar(
                        SnackBar(
                          content: Text('❌ Hata: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: Text(isEditing ? 'Güncelle' : 'Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  void _createReport(BuildContext context) {
    if (_selectedExpenseKeys.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExpenseReportScreen(
          expenseKeys: _selectedExpenseKeys.toList(),
          onReportCreated: () {
            setState(() {
              _isSelectionMode = false;
              _selectedExpenseKeys.clear();
            });
            _tabController.animateTo(1);
          },
        ),
      ),
    );
  }

  Widget _buildCollectionTypeChip({
    required CollectionType type,
    required CollectionType selectedType,
    required IconData icon,
    required String label,
    required Color color,
    required Color selectedColor,
    required VoidCallback onSelected,
  }) {
    final isSelected = selectedType == type;
    return SizedBox(
      width: 146,
      child: ChoiceChip(
        label: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? color : Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? color : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) onSelected();
        },
        selectedColor: selectedColor,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected
                ? color.withValues(alpha: 0.45)
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        elevation: isSelected ? 4 : 1,
        shadowColor:
            isSelected ? color.withValues(alpha: 0.25) : Colors.grey.shade200,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
    );
  }

  /// 💰 Tahsilat Girişi Dialogu
  void _showCollectionOptions(BuildContext context, Expense expense) {
    final formKey = GlobalKey<FormState>();
    CollectionType selectedType = CollectionType.eft;
    final noteController = TextEditingController();
    final dateController = TextEditingController(
      text: DateFormat('dd.MM.yyyy').format(DateTime.now()),
    );

    // 🎯 Tahsilat bilgilerini göster
    final currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.payments, color: Colors.green),
              SizedBox(width: 8),
              Text('Tahsilat Girişi'),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Masraf Bilgisi
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense.description,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tutar: ${NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(expense.amount)}',
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (expense.reportNumber != null)
                          Text(
                            'Rapor: ${expense.reportNumber}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Tahsilat Tipi
                  Text(
                    'Tahsilat Tipi',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildCollectionTypeChip(
                        type: CollectionType.eft,
                        selectedType: selectedType,
                        icon: Icons.account_balance,
                        label: 'EFT/Havale',
                        color: const Color(0xFF1565C0),
                        selectedColor: const Color(0xFFE3F2FD),
                        onSelected: () =>
                            setState(() => selectedType = CollectionType.eft),
                      ),
                      _buildCollectionTypeChip(
                        type: CollectionType.cash,
                        selectedType: selectedType,
                        icon: Icons.money,
                        label: 'Nakit',
                        color: const Color(0xFF2E7D32),
                        selectedColor: const Color(0xFFE8F5E9),
                        onSelected: () =>
                            setState(() => selectedType = CollectionType.cash),
                      ),
                      _buildCollectionTypeChip(
                        type: CollectionType.offset,
                        selectedType: selectedType,
                        icon: Icons.swap_horiz,
                        label: 'Mahsup',
                        color: const Color(0xFF6A1B9A),
                        selectedColor: const Color(0xFFF3E5F5),
                        onSelected: () => setState(
                            () => selectedType = CollectionType.offset),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Tahsilat Tarihi
                  TextFormField(
                    controller: dateController,
                    decoration: const InputDecoration(
                      labelText: 'Tahsilat Tarihi *',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v!.isEmpty ? 'Tarih zorunludur' : null,
                  ),
                  const SizedBox(height: 12),
                  // Not
                  TextFormField(
                    controller: noteController,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: const [
                      TurkishUpperCaseTextFormatter(),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Tahsilat Notu (Opsiyonel)',
                      hintText: 'Örn: Banka transferi yapıldı',
                      prefixIcon: Icon(Icons.note),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('İptal'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final expenseProvider =
                      Provider.of<ExpenseProvider>(context, listen: false);
                  final dialogNavigator = Navigator.of(ctx);
                  final rootMessenger = ScaffoldMessenger.of(context);
                  final dialogMessenger = ScaffoldMessenger.of(ctx);
                  try {
                    // 🎯 Güvenli tarih parse
                    final dateParts = dateController.text.trim().split('.');
                    if (dateParts.length != 3) {
                      throw FormatException('Geçersiz tarih formatı');
                    }

                    final day = int.tryParse(dateParts[0]);
                    final month = int.tryParse(dateParts[1]);
                    final year = int.tryParse(dateParts[2]);

                    if (day == null || month == null || year == null) {
                      throw FormatException('Geçersiz tarih değerleri');
                    }

                    if (day < 1 ||
                        day > 31 ||
                        month < 1 ||
                        month > 12 ||
                        year < 2000) {
                      throw FormatException(
                          'Tarih değerleri geçersiz aralıkta');
                    }

                    final collectionDate = DateTime(year, month, day);

                    // 🔊 Önce ses çal
                    await SoundService().playSaveSuccess();

                    await expenseProvider.collectExpense(
                      expense.key!,
                      type: selectedType,
                      date: collectionDate,
                      note: noteController.text.trim().isEmpty
                          ? null
                          : normalizeDescriptionText(noteController.text),
                    );

                    if (ctx.mounted) {
                      dialogNavigator.pop();
                    }

                    if (mounted) {
                      rootMessenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            '✅ ${expense.description} - ${currencyFormat.format(expense.amount)} tahsilat kaydedildi',
                          ),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  } catch (e) {
                    // 🔊 Hata sesi
                    await SoundService().playError();
                    debugPrint('🚨 Tahsilat kaydetme hatası: $e');
                    if (ctx.mounted) {
                      dialogMessenger.showSnackBar(
                        SnackBar(
                          content: Text('❌ Hata: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              icon: const Icon(Icons.check_circle),
              label: const Text('Tahsilatı Kaydet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
