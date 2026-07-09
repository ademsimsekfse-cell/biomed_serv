import 'dart:io';

import 'package:biomed_serv/models/customer.dart';
import 'package:biomed_serv/models/device.dart';
import 'package:biomed_serv/models/device_personel.dart';
import 'package:biomed_serv/models/stock.dart';
import 'package:biomed_serv/models/technician.dart';
import 'package:biomed_serv/providers/customer_provider.dart';
import 'package:biomed_serv/providers/device_provider.dart';
import 'package:biomed_serv/providers/technician_provider.dart';
import 'package:biomed_serv/screens/api_settings_screen.dart';
import 'package:biomed_serv/services/database_service.dart';
import 'package:biomed_serv/services/lan_auto_sync_service.dart';
import 'package:biomed_serv/services/lan_sync_service.dart';
import 'package:biomed_serv/services/technical_assignment_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DesktopSyncCenterScreen extends StatefulWidget {
  final int initialTab;

  const DesktopSyncCenterScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<DesktopSyncCenterScreen> createState() =>
      _DesktopSyncCenterScreenState();
}

class _DesktopSyncCenterScreenState extends State<DesktopSyncCenterScreen> {
  bool _busy = false;
  List<String> _localIps = [];
  String? _statusMessage;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    _loadLocalIps();
  }

  Future<void> _loadLocalIps() async {
    final ips = await context.read<LanAutoSyncService>().localIpv4Addresses();
    if (!mounted) return;
    setState(() => _localIps = ips);
  }

  Future<void> _retryServer() async {
    final autoSync = context.read<LanAutoSyncService>();
    setState(() {
      _busy = true;
      _statusMessage = null;
    });

    try {
      await autoSync.startCenterListening();
      await _loadLocalIps();
      setState(() => _statusMessage =
          'Merkez dinlemede. Mobil cihazlar bu bilgisayarı otomatik bulabilir.');
    } catch (e) {
      setState(() => _statusMessage = 'Senkron sunucusu baslatilamadi: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<_CenterOpsSnapshot> _loadCenterOpsSnapshot(
    DatabaseService db,
    LanAutoSyncService autoSync,
  ) async {
    final requests = await autoSync.pendingAccessRequests();
    final reviews = await autoSync.reviewItems();
    final pendingReviews = reviews.where((item) => !item.reviewed).length;

    return _CenterOpsSnapshot(
      pendingAccessRequests: requests.length,
      pendingReviewItems: pendingReviews,
      localIpCount: _localIps.length,
      assignedDeviceCount: db.devicesBox.values
          .where((device) => device.customer != null)
          .length,
      openFaultCount:
          db.faultTicketsBox.values.where((ticket) => ticket.isOpen).length,
    );
  }

  Device? _findDeviceBySerial(DatabaseService db, String? serialNumber) {
    if (serialNumber == null || serialNumber.trim().isEmpty) return null;
    final serial = serialNumber.trim().toLowerCase();
    for (final device in db.devicesBox.values) {
      if (device.serialNumber.trim().toLowerCase() == serial) {
        return device;
      }
    }
    return null;
  }

  String _normalizeStockText(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  Stock? _findImportedStockForReview(
      DatabaseService db, LanSyncReviewItem item) {
    final identifier = (item.identifier ?? '').trim().toLowerCase();
    final title = item.title.trim().toLowerCase();

    for (final stock in db.stocksBox.values) {
      final barcode = (stock.barcode ?? '').trim().toLowerCase();
      final referenceNo = (stock.referenceNo ?? '').trim().toLowerCase();
      final name = stock.name.trim().toLowerCase();
      if (identifier.isNotEmpty &&
          (barcode == identifier || referenceNo == identifier)) {
        return stock;
      }
      if (identifier.isNotEmpty && identifier == title && name == title) {
        return stock;
      }
      if (name == title) {
        return stock;
      }
    }
    return null;
  }

  _StockMergeSuggestion? _stockSuggestionForReview(
    DatabaseService db,
    LanSyncReviewItem item,
  ) {
    final imported = _findImportedStockForReview(db, item);
    if (imported == null) return null;

    final importedKey = imported.key;
    final importedBarcode = (imported.barcode ?? '').trim().toLowerCase();
    final importedRef = (imported.referenceNo ?? '').trim().toLowerCase();
    final importedName = imported.name.trim().toLowerCase();
    final importedNameNormalized = _normalizeStockText(imported.name);

    Stock? bestMatch;
    String? reason;
    var bestScore = 0;

    for (final candidate in db.stocksBox.values) {
      if (candidate.key == importedKey) continue;

      final candidateBarcode = (candidate.barcode ?? '').trim().toLowerCase();
      final candidateRef = (candidate.referenceNo ?? '').trim().toLowerCase();
      final candidateName = candidate.name.trim().toLowerCase();
      final candidateNameNormalized = _normalizeStockText(candidate.name);

      var score = 0;
      String? localReason;

      if (importedBarcode.isNotEmpty &&
          candidateBarcode.isNotEmpty &&
          importedBarcode == candidateBarcode) {
        score = 100;
        localReason = 'Ayni barkod bulundu';
      } else if (importedRef.isNotEmpty &&
          candidateRef.isNotEmpty &&
          importedRef == candidateRef) {
        score = 95;
        localReason = 'Ayni referans numarasi bulundu';
      } else if (importedNameNormalized.isNotEmpty &&
          candidateNameNormalized == importedNameNormalized) {
        score = 90;
        localReason = 'Isim neredeyse ayni';
      } else if (importedName.isNotEmpty &&
          candidateName.isNotEmpty &&
          (candidateName.contains(importedName) ||
              importedName.contains(candidateName))) {
        score = 70;
        localReason = 'Benzer isim bulundu';
      } else if (importedRef.isNotEmpty &&
          candidateRef.isNotEmpty &&
          (candidateRef.contains(importedRef) ||
              importedRef.contains(candidateRef))) {
        score = 65;
        localReason = 'Referans numarasi cok benzer';
      }

      if (score > bestScore) {
        bestScore = score;
        bestMatch = candidate;
        reason = localReason;
      }
    }

    if (bestMatch == null || bestScore < 65 || reason == null) {
      return null;
    }

    return _StockMergeSuggestion(
      imported: imported,
      candidate: bestMatch,
      reason: reason,
    );
  }

  Future<void> _mergeSuggestedStock(
    LanSyncReviewItem item,
    _StockMergeSuggestion suggestion,
  ) async {
    final db = context.read<DatabaseService>();
    final autoSync = context.read<LanAutoSyncService>();
    final importedKey = suggestion.imported.key;
    final candidateKey = suggestion.candidate.key;
    if (importedKey is! int || candidateKey is! int) {
      setState(() {
        _statusMessage = 'Stok birlestirme icin gerekli anahtarlar okunamadi.';
      });
      return;
    }

    suggestion.candidate.quantity += suggestion.imported.quantity;
    suggestion.candidate.barcode ??= suggestion.imported.barcode;
    suggestion.candidate.referenceNo ??= suggestion.imported.referenceNo;
    if (suggestion.candidate.criticalStockThreshold <
        suggestion.imported.criticalStockThreshold) {
      suggestion.candidate.criticalStockThreshold =
          suggestion.imported.criticalStockThreshold;
    }

    await db.stocksBox.put(candidateKey, suggestion.candidate);
    await db.stocksBox.delete(importedKey);
    await autoSync.markReviewItemReviewed(item.id);
    if (!mounted) return;
    setState(() {
      _statusMessage =
          '${suggestion.imported.name} stogu, ${suggestion.candidate.name} karti ile birlestirildi.';
    });
  }

  Future<void> _showQuickAssignSheet(LanSyncReviewItem item) async {
    final db = context.read<DatabaseService>();
    final assignmentService = context.read<TechnicalAssignmentService>();
    final deviceProvider = context.read<DeviceProvider>();
    final customerProvider = context.read<CustomerProvider>();
    final technicianProvider = context.read<TechnicianProvider>();
    final autoSync = context.read<LanAutoSyncService>();

    final device = _findDeviceBySerial(db, item.identifier);
    if (device == null) {
      setState(() {
        _statusMessage =
            'Hizli atama icin cihaz bulunamadi. Seri no: ${item.identifier ?? '-'}';
      });
      return;
    }

    final customers = [...customerProvider.customers]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final technicians = [...technicianProvider.technicians]..sort(
        (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));

    if (customers.isEmpty || technicians.isEmpty) {
      setState(() {
        _statusMessage =
            'Hizli atama icin en az bir kurum ve bir teknisyen kaydi gerekli.';
      });
      return;
    }

    Customer? selectedCustomer =
        device.customer is Customer ? device.customer as Customer : null;
    final existingAssignment = assignmentService.assignmentForDevice(device);
    Technician? selectedTechnician;
    for (final technician in technicians) {
      final technicianId = LanSyncService.technicianAccessId(technician);
      if (existingAssignment != null &&
          existingAssignment.technicianId == technicianId) {
        selectedTechnician = technician;
        break;
      }
    }
    selectedTechnician ??= technicians.first;

    bool setResponsiblePerson = false;
    bool assignCustomerDefault = false;

    DevicePersonel? buildResponsiblePerson(Customer customer) {
      final preferredName = customer.unitResponsibleName?.trim() ?? '';
      if (preferredName.isEmpty) return null;
      final parts = preferredName.split(RegExp(r'\s+'));
      final firstName = parts.first;
      final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '-';
      return DevicePersonel(
        firstName: firstName,
        lastName: lastName,
        phone: customer.unitResponsiblePhone?.trim().isNotEmpty == true
            ? customer.unitResponsiblePhone!.trim()
            : null,
        title: 'Birim Sorumlusu',
        customer: customer,
        assignedDate: DateTime.now(),
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final chainDevices = deviceProvider.linkedDevicesForDevice(device);
            final chainCount = chainDevices.length;
            final canCreateResponsibleFromUnit =
                selectedCustomer?.unitResponsibleName?.trim().isNotEmpty ==
                    true;

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Hizli Cihaz Atamasi',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${device.brand} / ${device.model} / ${device.serialNumber}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(
                              avatar: const Icon(Icons.hub, size: 16),
                              label: Text(
                                chainCount > 1
                                    ? 'Bagli zincir: $chainCount cihaz'
                                    : 'Bagimsiz cihaz',
                              ),
                            ),
                            Chip(
                              avatar:
                                  const Icon(Icons.person_outline, size: 16),
                              label: Text(item.technicianName),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Customer>(
                    initialValue: selectedCustomer,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Kurum secimi',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                    items: customers
                        .map(
                          (customer) => DropdownMenuItem(
                            value: customer,
                            child: Text(
                              customer.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setSheetState(() {
                      selectedCustomer = value;
                      if (value?.unitResponsibleName?.trim().isNotEmpty !=
                          true) {
                        setResponsiblePerson = false;
                      }
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Technician>(
                    initialValue: selectedTechnician,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Teknisyen secimi',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.engineering_outlined),
                    ),
                    items: technicians
                        .map(
                          (technician) => DropdownMenuItem(
                            value: technician,
                            child: Text(
                              technician.fullName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setSheetState(() {
                      selectedTechnician = value;
                    }),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: setResponsiblePerson,
                    onChanged: canCreateResponsibleFromUnit
                        ? (value) =>
                            setSheetState(() => setResponsiblePerson = value)
                        : null,
                    title:
                        const Text('Birim bilgisinden cihaz sorumlusu olustur'),
                    subtitle: Text(
                      selectedCustomer == null
                          ? 'Once kurum secildiginde aktif olur.'
                          : (selectedCustomer!.unitResponsibleName
                                      ?.trim()
                                      .isNotEmpty ==
                                  true)
                              ? 'Kurum yetkilisi degil, sadece birim sorumlusu cihaz sorumlusu olur.'
                              : 'Bu kurumda birim sorumlusu yok; kurum yetkilisi cihaz sorumlusu yapilmaz.',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: assignCustomerDefault,
                    onChanged: (value) =>
                        setSheetState(() => assignCustomerDefault = value),
                    title: const Text('Bu kurum icin varsayilan teknisyen yap'),
                    subtitle: const Text(
                      'Ayni kuruma sonradan baglanan diger cihazlar bu atamayi miras alabilir.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () async {
                      if (selectedCustomer == null ||
                          selectedTechnician == null) {
                        setState(() {
                          _statusMessage =
                              'Hizli atama icin kurum ve teknisyen secimi gerekli.';
                        });
                        return;
                      }

                      final deviceKey = device.key;
                      if (deviceKey is! int) {
                        setState(() {
                          _statusMessage =
                              'Bu cihazin kayit anahtari okunamadi, atama tamamlanamadi.';
                        });
                        return;
                      }

                      device.customer = selectedCustomer;
                      if (setResponsiblePerson) {
                        final personel =
                            buildResponsiblePerson(selectedCustomer!);
                        if (personel != null &&
                            deviceProvider.hasResponsiblePersonConflict(
                              personel: personel,
                              targetDevice: device,
                              targetCustomer: selectedCustomer,
                            )) {
                          setState(() {
                            _statusMessage =
                                'Ayni sorumlu kisi farkli kurum cihazlarina atanamaz. Lutfen cihaz sorumlusunu sonra duzenle.';
                          });
                          return;
                        }
                        device.responsiblePerson = personel;
                      }

                      await deviceProvider.updateDevice(deviceKey, device);
                      await assignmentService.assignDevice(
                        device: device,
                        technician: selectedTechnician!,
                        note: 'Merkez hizli atamasi',
                      );
                      if (assignCustomerDefault) {
                        await assignmentService.assignCustomer(
                          customer: selectedCustomer!,
                          technician: selectedTechnician!,
                          note: 'Merkez hizli atama varsayilani',
                        );
                      }
                      await autoSync.markReviewItemReviewed(item.id);
                      if (!mounted || !sheetContext.mounted) return;
                      Navigator.pop(sheetContext);
                      setState(() {
                        _statusMessage =
                            '${device.serialNumber} cihazi ${selectedCustomer!.name} kurumuna ve ${selectedTechnician!.fullName} teknisyenine baglandi.';
                      });
                    },
                    icon: const Icon(Icons.done_all),
                    label: const Text('Atamayi Kaydet'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<DatabaseService>();
    final autoSync = context.watch<LanAutoSyncService>();
    final initialTab =
        widget.initialTab >= 0 && widget.initialTab < 4 ? widget.initialTab : 0;

    Widget tabBody(List<Widget> children) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1) const SizedBox(height: 16),
          ],
        ],
      );
    }

    return DefaultTabController(
      length: 4,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Desktop Senkron Merkezi'),
          backgroundColor: const Color(0xFF0F766E),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              const Tab(
                icon: Icon(Icons.dashboard_outlined),
                text: 'Genel Durum',
              ),
              Tab(
                icon: Badge(
                  isLabelVisible: autoSync.pendingAccessCount > 0,
                  label: Text('${autoSync.pendingAccessCount}'),
                  child: const Icon(Icons.verified_user_outlined),
                ),
                text: 'Eşleşme Onayları',
              ),
              const Tab(
                icon: Icon(Icons.move_to_inbox_outlined),
                text: 'Gelen Veriler ve Görevler',
              ),
              const Tab(
                icon: Icon(Icons.settings_outlined),
                text: 'Merkez Ayarları',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            tabBody([
              _buildHero(context),
              _buildOperationsOverviewCard(db, autoSync),
              _buildNextStepsCard(autoSync),
              _buildStats(db),
              _buildDesktopServerCard(autoSync),
              _buildRemoteGatewayCard(autoSync),
              if (_statusMessage != null) _buildStatusCard(),
              if (autoSync.lastMessage != null)
                _buildAutoSyncStatusCard(autoSync),
            ]),
            tabBody([
              _buildAccessRequestsCard(autoSync),
              _buildNextStepsCard(autoSync),
            ]),
            tabBody([
              _buildReviewQueueCard(autoSync),
              _buildTechnicianOpsCard(db),
              if (autoSync.lastResult != null)
                _buildResultCard(autoSync.lastResult!),
            ]),
            tabBody([
              _buildSyncProfileCard(autoSync),
              _buildDesktopServerCard(autoSync),
              _buildRemoteGatewayCard(autoSync),
              if (autoSync.lastMessage != null)
                _buildAutoSyncStatusCard(autoSync),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.hub,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Biomed Servis Merkez',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Bu bilgisayari merkeze cevir, teknisyenleri bagla ve saha verilerini tek yerde topla.',
                  style: TextStyle(
                    color: Colors.white70,
                    height: 1.3,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationsOverviewCard(
    DatabaseService db,
    LanAutoSyncService autoSync,
  ) {
    return FutureBuilder<_CenterOpsSnapshot>(
      future: _loadCenterOpsSnapshot(db, autoSync),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final pendingApprovals = data?.pendingAccessRequests ?? 0;
        final pendingReviews = data?.pendingReviewItems ?? 0;
        final lastSyncText = autoSync.lastSyncAt == null
            ? 'Henuz veri akisi yok'
            : _formatReviewTime(autoSync.lastSyncAt!);
        final recommendation = !autoSync.isListening
            ? 'Ilk adim olarak merkezi dinlemeye alip teknik ekip baglantilarini acalim.'
            : pendingApprovals > 0
                ? 'Bekleyen teknisyen erisim onaylarini tamamlayalim.'
                : pendingReviews > 0
                    ? 'Yeni gelen cihaz ve stok onerilerini gozden gecirelim.'
                    : 'Merkez hazir. Simdi cihaz, servis ve masraf akislarini rahatca toplayabiliriz.';

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader(
                  icon: Icons.space_dashboard_outlined,
                  title: 'Genel Durum',
                  subtitle:
                      'Baglantilarin ve bekleyen islerin ozetini buradan gor.',
                  color: const Color(0xFF1565C0),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildOpsBadge(
                      label: 'Merkez durumu',
                      value: autoSync.isListening ? 'Dinliyor' : 'Bekliyor',
                      icon: autoSync.isListening
                          ? Icons.cloud_done
                          : Icons.cloud_off,
                      accent:
                          autoSync.isListening ? Colors.green : Colors.orange,
                    ),
                    _buildOpsBadge(
                      label: 'Ag adresi',
                      value: '${data?.localIpCount ?? _localIps.length}',
                      icon: Icons.lan,
                      accent: Colors.blue,
                    ),
                    _buildOpsBadge(
                      label: 'Baglanti istegi',
                      value: '$pendingApprovals',
                      icon: Icons.verified_user_outlined,
                      accent: Colors.deepPurple,
                    ),
                    _buildOpsBadge(
                      label: 'Kontrol bekleyen',
                      value: '$pendingReviews',
                      icon: Icons.fact_check_outlined,
                      accent: Colors.teal,
                    ),
                    _buildOpsBadge(
                      label: 'Atanmis cihaz',
                      value: '${data?.assignedDeviceCount ?? 0}',
                      icon: Icons.devices_other,
                      accent: Colors.indigo,
                    ),
                    _buildOpsBadge(
                      label: 'Acik is',
                      value: '${data?.openFaultCount ?? 0}',
                      icon: Icons.build_circle_outlined,
                      accent: Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6FAFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD9E7F7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sana onerim',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        recommendation,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Son hareket: $lastSyncText',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
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
        );
      },
    );
  }

  Widget _buildOpsBadge({
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 170),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: accent.withValues(alpha: 0.14),
            child: Icon(icon, size: 17, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveAllAccessRequests(LanAutoSyncService autoSync) async {
    final requests = await autoSync.pendingAccessRequests();
    if (requests.isEmpty) {
      setState(() => _statusMessage = 'Bekleyen baglanti istegi yok.');
      return;
    }

    setState(() => _busy = true);
    try {
      for (final request in requests) {
        await autoSync.approveAccess(request.accessKey);
      }
      if (!mounted) return;
      setState(() {
        _statusMessage =
            '${requests.length} teknisyen icin baglanti onayi tamamlandi.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markAllReviewItemsCompleted(LanAutoSyncService autoSync) async {
    final items = await autoSync.reviewItems();
    if (items.isEmpty) {
      setState(() => _statusMessage = 'Bekleyen yeni kayit onerisi yok.');
      return;
    }

    setState(() => _busy = true);
    try {
      for (final item in items) {
        await autoSync.markReviewItemReviewed(item.id);
      }
      if (!mounted) return;
      setState(() {
        _statusMessage =
            '${items.length} yeni kayit onerisi tek adimda tamamlandi.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _buildNextStepsCard(LanAutoSyncService autoSync) {
    return FutureBuilder<_CenterOpsSnapshot>(
      future: _loadCenterOpsSnapshot(context.read<DatabaseService>(), autoSync),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final pendingApprovals = data?.pendingAccessRequests ?? 0;
        final pendingReviews = data?.pendingReviewItems ?? 0;

        final steps = [
          (
            autoSync.isListening,
            'Merkezi ac',
            'Bu bilgisayari baglantiya hazir duruma getir.',
          ),
          (
            pendingApprovals == 0,
            'Teknisyenleri onayla',
            pendingApprovals == 0
                ? 'Bekleyen baglanti istegi yok.'
                : '$pendingApprovals istek onay bekliyor.',
          ),
          (
            pendingReviews == 0,
            'Yeni kayitlari kontrol et',
            pendingReviews == 0
                ? 'Bekleyen yeni kayit yok.'
                : '$pendingReviews kayit son kontrolden gecmeyi bekliyor.',
          ),
        ];

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader(
                  icon: Icons.flag_outlined,
                  title: 'Ilk Ne Yapalim?',
                  subtitle:
                      'Bu ekranda en mantikli sirayi buradan gorebilirsin.',
                  color: Colors.orange,
                ),
                const SizedBox(height: 12),
                ...steps.map(
                  (step) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: step.$1
                          ? Colors.green.withValues(alpha: 0.06)
                          : Colors.orange.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: step.$1
                            ? Colors.green.withValues(alpha: 0.14)
                            : Colors.orange.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          step.$1
                              ? Icons.check_circle_outline
                              : Icons.radio_button_unchecked,
                          color: step.$1 ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                step.$2,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                step.$3,
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStats(DatabaseService db) {
    final items = [
      _StatItem('Musteri', db.customersBox.length, Icons.business),
      _StatItem('Cihaz', db.devicesBox.length, Icons.devices),
      _StatItem('Servis', db.serviceFormsBox.length, Icons.description),
      _StatItem('Bakim', db.maintenanceFormsBox.length, Icons.fact_check),
      _StatItem('Ariza', db.faultTicketsBox.length, Icons.build),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 900 ? 5 : 2;
        return GridView.count(
          crossAxisCount: count,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: count == 5 ? 2.2 : 2.6,
          children: items
              .map(
                (item) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              const Color(0xFF1565C0).withValues(alpha: 0.1),
                          child: Icon(
                            item.icon,
                            color: const Color(0xFF1565C0),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item.value.toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                ),
                              ),
                              Text(
                                item.label,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildDesktopServerCard(LanAutoSyncService autoSync) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(
              icon: Icons.desktop_windows,
              title: 'Desktop Merkez',
              subtitle: _isDesktop
                  ? 'Aynı ağdaki telefonlar bu bilgisayarı otomatik bulur.'
                  : 'Test icin bu cihazdan da acilabilir.',
              color: const Color(0xFF0F766E),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy || autoSync.isListening ? null : _retryServer,
              icon: Icon(
                autoSync.isListening ? Icons.check_circle : Icons.refresh,
              ),
              label: Text(
                autoSync.isListening
                    ? 'Merkez Otomatik Çalışıyor'
                    : 'Yeniden Dene',
              ),
            ),
            const SizedBox(height: 12),
            if (autoSync.isListening)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Merkez hazır',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _localIps.isEmpty
                          ? 'Yerel IP bulunamadı. Ağ bağlantısını kontrol edin.'
                          : 'Mobil cihazlar aşağıdaki adreslerden merkezi otomatik bulabilir.',
                    ),
                    if (_localIps.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final ip in _localIps)
                            Chip(
                              avatar: const Icon(Icons.lan_outlined, size: 16),
                              label: Text(
                                '$ip:${autoSync.localApiPort}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(
                          Icons.security_outlined,
                          size: 17,
                          color: Color(0xFF2E7D32),
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'SetupWizard, ${LanSyncService.defaultPort}/TCP API ve ${LanSyncService.discoveryPort}/UDP otomatik keşif izinlerini yalnızca yerel alt ağ için ekler.',
                            style: TextStyle(fontSize: 12),
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
    );
  }

  Widget _buildRemoteGatewayCard(LanAutoSyncService autoSync) {
    final configured = autoSync.remoteGatewayEnabled;
    final reachable = autoSync.isRemoteReachable;
    final color = !configured
        ? Colors.blueGrey
        : reachable
            ? Colors.green
            : Colors.orange;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(
              icon: Icons.cloud_outlined,
              title: 'Uzak Gateway',
              subtitle: !configured
                  ? 'Yerel ağ dışında çalışmak için opsiyonel internet relay merkezi.'
                  : reachable
                      ? 'Gateway bağlantısı doğrulandı ve uzak kuyruk izleniyor.'
                      : 'Gateway yapılandırıldı; bağlantı henüz doğrulanmadı.',
              color: color,
            ),
            if (configured) ...[
              const SizedBox(height: 10),
              SelectableText(
                autoSync.remoteGatewayUrl,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: !configured || autoSync.isSyncing
                      ? null
                      : () => autoSync.processRemoteCenter(),
                  icon: const Icon(Icons.cloud_sync_outlined),
                  label: const Text('Uzak Kuyruğu İşle'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ApiSettingsScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Gateway Ayarları'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessRequestsCard(LanAutoSyncService autoSync) {
    return FutureBuilder<List<LanAccessRequest>>(
      future: autoSync.pendingAccessRequests(),
      builder: (context, snapshot) {
        final requests = snapshot.data ?? const <LanAccessRequest>[];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader(
                  icon: Icons.verified_user_outlined,
                  title: 'Baglanti Onaylari',
                  subtitle:
                      'Sadece izin verdigin teknisyenler bu merkeze veri gonderebilir.',
                  color: Colors.deepPurple,
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: requests.isEmpty || _busy
                            ? null
                            : () => _approveAllAccessRequests(autoSync),
                        icon: const Icon(Icons.done_all),
                        label: const Text('Tumunu Onayla'),
                      ),
                      if (requests.isNotEmpty)
                        Chip(
                          avatar: const Icon(Icons.schedule, size: 16),
                          label: Text('${requests.length} istek bekliyor'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const LinearProgressIndicator()
                else if (requests.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Text('Bekleyen baglanti onayi yok.'),
                  )
                else
                  ...requests.map(
                    (request) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.deepPurple.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                Colors.deepPurple.withValues(alpha: 0.12),
                            child: Text(
                              request.technicianName.isEmpty
                                  ? '?'
                                  : request.technicianName[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.deepPurple,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  request.technicianName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  [
                                    if (request.title != null) request.title,
                                    request.sourceDevice,
                                    'Cihaz: ${request.deviceIdentityLabel}',
                                    if (request.sourceIp != null)
                                      'IP: ${request.sourceIp}',
                                    request.phone,
                                    request.email,
                                  ].whereType<String>().join(' - '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Iptal Et',
                            onPressed: () async {
                              await autoSync.rejectAccess(request.accessKey);
                              if (mounted) setState(() {});
                            },
                            icon: const Icon(Icons.close, color: Colors.red),
                          ),
                          FilledButton.icon(
                            onPressed: () async {
                              await autoSync.approveAccess(request.accessKey);
                              if (mounted) setState(() {});
                            },
                            icon: const Icon(Icons.check),
                            label: const Text('Onay Ver'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatReviewTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}.${two(value.month)}.${value.year} ${two(value.hour)}:${two(value.minute)}';
  }

  Widget _buildReviewQueueCard(LanAutoSyncService autoSync) {
    return FutureBuilder<List<LanSyncReviewItem>>(
      future: autoSync.reviewItems(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <LanSyncReviewItem>[];
        final db = context.read<DatabaseService>();
        final assignmentService = context.watch<TechnicalAssignmentService>();
        final grouped = <String, List<LanSyncReviewItem>>{};
        for (final item in items) {
          grouped.putIfAbsent(item.technicianName, () => []).add(item);
        }
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader(
                  icon: Icons.playlist_add_check_circle_outlined,
                  title: 'Kontrol Bekleyen Yeni Kayitlar',
                  subtitle:
                      'Yeni gelen cihaz ve stoklari burada kisaca kontrol edip yerlerine baglayabilirsin.',
                  color: Colors.teal,
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: items.isEmpty || _busy
                            ? null
                            : () => _markAllReviewItemsCompleted(autoSync),
                        icon: const Icon(Icons.playlist_add_check),
                        label: const Text('Tumunu Tamamla'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () async {
                                await autoSync.clearReviewedItems();
                                if (mounted) setState(() {});
                              },
                        icon: const Icon(Icons.cleaning_services_outlined),
                        label: const Text('Tamamlananlari Temizle'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const LinearProgressIndicator()
                else if (items.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Text(
                      'Bekleyen yeni cihaz veya stok onerisi yok.',
                    ),
                  )
                else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal.shade100),
                    ),
                    child: Text(
                      '${items.length} yeni kayit geldi. Uygunsa tamamlandi diyebilir ya da hemen baglayabilirsin.',
                      style: TextStyle(
                        color: Colors.teal.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...grouped.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...entry.value.map(
                            (item) {
                              final stockSuggestion = item.isStock
                                  ? _stockSuggestionForReview(db, item)
                                  : null;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.grey.shade200),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: item.isDevice
                                          ? Colors.blue.shade50
                                          : Colors.orange.shade50,
                                      child: Icon(
                                        item.isDevice
                                            ? Icons.devices
                                            : Icons.inventory_2,
                                        color: item.isDevice
                                            ? Colors.blue
                                            : Colors.orange,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (item.isDevice) ...[
                                            Builder(
                                              builder: (context) {
                                                final device =
                                                    _findDeviceBySerial(
                                                        db, item.identifier);
                                                final customer =
                                                    device?.customer is Customer
                                                        ? device!.customer
                                                            as Customer
                                                        : null;
                                                final assignment = device ==
                                                        null
                                                    ? null
                                                    : assignmentService
                                                        .assignmentForDevice(
                                                            device);
                                                final summary = [
                                                  if (customer != null)
                                                    customer.name,
                                                  if (assignment != null)
                                                    assignment.technicianName,
                                                ].join(' - ');
                                                if (summary.isEmpty) {
                                                  return const SizedBox
                                                      .shrink();
                                                }
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          bottom: 6),
                                                  child: Text(
                                                    summary,
                                                    style: TextStyle(
                                                      color:
                                                          Colors.teal.shade700,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                          if (item.isStock &&
                                              stockSuggestion != null) ...[
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 6),
                                              child: Text(
                                                '${stockSuggestion.reason}: ${stockSuggestion.candidate.name}',
                                                style: TextStyle(
                                                  color: Colors.orange.shade800,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                          Text(
                                            item.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          if (item.subtitle
                                              .trim()
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              item.subtitle,
                                              style: TextStyle(
                                                color: Colors.grey.shade700,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              Chip(
                                                avatar: Icon(
                                                  item.isDevice
                                                      ? Icons.memory
                                                      : Icons.qr_code_2,
                                                  size: 16,
                                                ),
                                                label: Text(
                                                  item.identifier ?? 'Kod yok',
                                                ),
                                              ),
                                              Chip(
                                                avatar: const Icon(
                                                    Icons.phone_android,
                                                    size: 16),
                                                label: Text(item.sourceDevice),
                                              ),
                                              Chip(
                                                avatar: const Icon(
                                                    Icons.schedule,
                                                    size: 16),
                                                label: Text(_formatReviewTime(
                                                    item.importedAt)),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        if (item.isDevice)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 8),
                                            child: OutlinedButton.icon(
                                              onPressed: () =>
                                                  _showQuickAssignSheet(item),
                                              icon: const Icon(Icons.bolt),
                                              label: const Text('Hemen Bagla'),
                                            ),
                                          ),
                                        if (item.isStock &&
                                            stockSuggestion != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 8),
                                            child: OutlinedButton.icon(
                                              onPressed: () =>
                                                  _mergeSuggestedStock(
                                                item,
                                                stockSuggestion,
                                              ),
                                              icon:
                                                  const Icon(Icons.merge_type),
                                              label: const Text(
                                                'Mevcut Stokla Birlestir',
                                              ),
                                            ),
                                          ),
                                        FilledButton.tonalIcon(
                                          onPressed: () async {
                                            await autoSync
                                                .markReviewItemReviewed(
                                                    item.id);
                                            if (mounted) setState(() {});
                                          },
                                          icon: const Icon(Icons.done_all),
                                          label: const Text('Tamamlandi'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTechnicianOpsCard(DatabaseService db) {
    final technicians = context.watch<TechnicianProvider>().technicians;
    final assignmentService = context.watch<TechnicalAssignmentService>();

    if (technicians.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _buildCardHeader(
            icon: Icons.groups_2_outlined,
            title: 'Teknisyen Durumu',
            subtitle:
                'Burada bilgi gorebilmek icin once desktop tarafinda teknisyen kaydi olmali.',
            color: Colors.deepOrange,
          ),
        ),
      );
    }

    final cards = technicians.map((technician) {
      final technicianId = LanSyncService.technicianAccessId(technician);
      final deviceCount = assignmentService.deviceAssignments
          .where((assignment) => assignment.technicianId == technicianId)
          .length;
      final customerCount = assignmentService.customerAssignments
          .where((assignment) => assignment.technicianId == technicianId)
          .length;
      final serviceCount = db.serviceFormsBox.values
          .where((form) =>
              (form.technicianName ?? '').trim() == technician.fullName)
          .length;
      final maintenanceCount = db.maintenanceFormsBox.values
          .where((form) =>
              (form.technicianName ?? '').trim() == technician.fullName)
          .length;
      final expenseReportCount = db.expenseReportsBox.values
          .where((report) => report.technician.fullName == technician.fullName)
          .length;

      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showTechnicianDetailSheet(technician),
        child: Container(
          width: 260,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blueGrey.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      technician.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.blueGrey.shade400),
                ],
              ),
              if ((technician.title ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  technician.title!,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildOpsChip(Icons.devices, 'Cihaz', deviceCount),
                  _buildOpsChip(Icons.business, 'Kurum', customerCount),
                  _buildOpsChip(Icons.description, 'Servis', serviceCount),
                  _buildOpsChip(
                      Icons.fact_check_outlined, 'Bakim', maintenanceCount),
                  _buildOpsChip(Icons.receipt_long_outlined, 'Masraf',
                      expenseReportCount),
                ],
              ),
            ],
          ),
        ),
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(
              icon: Icons.groups_2_outlined,
              title: 'Teknisyen Durumu',
              subtitle:
                  'Hangi teknisyende ne kadar cihaz, kurum ve is oldugunu buradan gor.',
              color: Colors.blueGrey,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: cards,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTechnicianDetailSheet(Technician technician) async {
    final db = context.read<DatabaseService>();
    final assignmentService = context.read<TechnicalAssignmentService>();
    final technicianId = LanSyncService.technicianAccessId(technician);

    final customerAssignments = assignmentService.customerAssignments
        .where((assignment) => assignment.technicianId == technicianId)
        .toList();
    final deviceAssignments = assignmentService.deviceAssignments
        .where((assignment) => assignment.technicianId == technicianId)
        .toList();

    final assignedCustomers = customerAssignments
        .map((assignment) => _findCustomerForAssignment(db, assignment))
        .whereType<Customer>()
        .toList();
    final assignedDevices = deviceAssignments
        .map((assignment) => _findDeviceBySerial(db, assignment.targetId))
        .whereType<Device>()
        .toList();

    final serviceForms = db.serviceFormsBox.values
        .where(
            (form) => (form.technicianName ?? '').trim() == technician.fullName)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final maintenanceForms = db.maintenanceFormsBox.values
        .where(
            (form) => (form.technicianName ?? '').trim() == technician.fullName)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final expenseReports = db.expenseReportsBox.values
        .where((report) => report.technician.fullName == technician.fullName)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final faultTickets = db.faultTicketsBox.values
        .where(
          (ticket) =>
              ticket.assignedTechnicianId == technicianId ||
              (ticket.technicianName ?? '').trim() == technician.fullName,
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final openFaultCount = faultTickets.where((ticket) => ticket.isOpen).length;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.82,
          minChildSize: 0.55,
          maxChildSize: 0.96,
          builder: (context, controller) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              technician.fullName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              [
                                if ((technician.title ?? '').trim().isNotEmpty)
                                  technician.title!,
                                if ((technician.phone ?? '').trim().isNotEmpty)
                                  technician.phone!,
                                if ((technician.email ?? '').trim().isNotEmpty)
                                  technician.email!,
                              ].join(' - '),
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildOpsChip(Icons.business, 'Atanan Kurum',
                          assignedCustomers.length),
                      _buildOpsChip(Icons.devices, 'Atanan Cihaz',
                          assignedDevices.length),
                      _buildOpsChip(Icons.build_circle_outlined, 'Acik Ariza',
                          openFaultCount),
                      _buildOpsChip(
                          Icons.description, 'Servis', serviceForms.length),
                      _buildOpsChip(Icons.fact_check_outlined, 'Bakim',
                          maintenanceForms.length),
                      _buildOpsChip(Icons.receipt_long_outlined, 'Masraf',
                          expenseReports.length),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      controller: controller,
                      children: [
                        _buildDetailSection(
                          title: 'Atanan Kurumlar',
                          icon: Icons.business,
                          children: assignedCustomers.isEmpty
                              ? [
                                  _buildEmptyTile(
                                      'Bu teknisyen icin kurum atamasi yok.')
                                ]
                              : assignedCustomers
                                  .take(8)
                                  .map(
                                    (customer) => _buildInfoTile(
                                      title: customer.name,
                                      subtitle: [
                                        customer.authorizedPerson,
                                        customer.phone,
                                      ]
                                          .where((value) =>
                                              value.trim().isNotEmpty)
                                          .join(' - '),
                                      leading: Icons.apartment,
                                    ),
                                  )
                                  .toList(),
                        ),
                        const SizedBox(height: 12),
                        _buildDetailSection(
                          title: 'Atanan Cihazlar',
                          icon: Icons.devices,
                          children: assignedDevices.isEmpty
                              ? [
                                  _buildEmptyTile(
                                      'Bu teknisyen icin cihaz atamasi yok.')
                                ]
                              : assignedDevices
                                  .take(10)
                                  .map(
                                    (device) => _buildInfoTile(
                                      title: device.name,
                                      subtitle:
                                          '${device.brand} / ${device.model} / ${device.serialNumber}',
                                      leading: Icons.memory_outlined,
                                    ),
                                  )
                                  .toList(),
                        ),
                        const SizedBox(height: 12),
                        _buildDetailSection(
                          title: 'Son Servis Formlari',
                          icon: Icons.description,
                          children: serviceForms.isEmpty
                              ? [_buildEmptyTile('Servis formu kaydi yok.')]
                              : serviceForms
                                  .take(6)
                                  .map(
                                    (form) => _buildInfoTile(
                                      title: form.formNumber,
                                      subtitle:
                                          '${form.customer.name} / ${form.device.serialNumber} / ${_formatReviewTime(form.createdAt)}',
                                      leading: Icons.receipt_long,
                                    ),
                                  )
                                  .toList(),
                        ),
                        const SizedBox(height: 12),
                        _buildDetailSection(
                          title: 'Bakim Gecmisi',
                          icon: Icons.fact_check_outlined,
                          children: maintenanceForms.isEmpty
                              ? [_buildEmptyTile('Bakim formu kaydi yok.')]
                              : maintenanceForms
                                  .take(6)
                                  .map(
                                    (form) => _buildInfoTile(
                                      title: form.formNumber,
                                      subtitle:
                                          '${form.customer.name} / ${form.device.serialNumber} / ${form.maintenancePeriod}',
                                      leading: Icons.build_outlined,
                                    ),
                                  )
                                  .toList(),
                        ),
                        const SizedBox(height: 12),
                        _buildDetailSection(
                          title: 'Masraf Raporlari',
                          icon: Icons.receipt_long_outlined,
                          children: expenseReports.isEmpty
                              ? [_buildEmptyTile('Masraf raporu kaydi yok.')]
                              : expenseReports
                                  .take(6)
                                  .map(
                                    (report) => _buildInfoTile(
                                      title: report.reportNumber,
                                      subtitle:
                                          'Toplam ${report.totalAmount.toStringAsFixed(2)} / ${report.isCollected ? 'Tahsil edildi' : 'Tahsil bekliyor'}',
                                      leading:
                                          Icons.account_balance_wallet_outlined,
                                    ),
                                  )
                                  .toList(),
                        ),
                        const SizedBox(height: 12),
                        _buildDetailSection(
                          title: 'Ariza ve Is Yukleri',
                          icon: Icons.warning_amber_outlined,
                          children: faultTickets.isEmpty
                              ? [_buildEmptyTile('Ariza kaydi yok.')]
                              : faultTickets
                                  .take(8)
                                  .map(
                                    (ticket) => _buildInfoTile(
                                      title: ticket.ticketNumber,
                                      subtitle:
                                          '${ticket.customer.name} / ${ticket.device.serialNumber} / ${ticket.statusText}',
                                      leading: ticket.isOpen
                                          ? Icons.pending_actions
                                          : Icons.check_circle_outline,
                                    ),
                                  )
                                  .toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Customer? _findCustomerForAssignment(
    DatabaseService db,
    TechnicalAssignment assignment,
  ) {
    for (final customer in db.customersBox.values) {
      final keyMatch = customer.key != null &&
          assignment.targetId == 'customer_${customer.key}';
      final nameMatch = customer.name.trim().toLowerCase() ==
          assignment.targetName.trim().toLowerCase();
      if (keyMatch || nameMatch) {
        return customer;
      }
    }
    return null;
  }

  Widget _buildDetailSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.blueGrey),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required String title,
    required String subtitle,
    required IconData leading,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.blueGrey.shade50,
            child: Icon(leading, color: Colors.blueGrey, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTile(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        text,
        style: TextStyle(color: Colors.grey.shade700),
      ),
    );
  }

  Widget _buildOpsChip(IconData icon, String label, int value) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text('$label: $value'),
    );
  }

  Widget _buildSyncProfileCard(LanAutoSyncService autoSync) {
    final options = [
      (
        LanSyncService.syncIncludeCompanyInfoKey,
        'Sirket bilgileri',
        'Mobil ilk kurulumda firma karti ve iletisim bilgileri gitsin.',
        Icons.apartment,
      ),
      (
        LanSyncService.syncIncludeCustomersKey,
        'Musteriler',
        'Cari ve kurum kayitlari mobile aktarilsin.',
        Icons.business,
      ),
      (
        LanSyncService.syncIncludeDevicesKey,
        'Cihazlar',
        'Atanan cihazlar ve moduler baglantilari mobile gitsin.',
        Icons.devices,
      ),
      (
        LanSyncService.syncIncludeServiceFormsKey,
        'Servis gecmisi',
        'Cihaz servis formlari mobile gecmis olarak insin.',
        Icons.description,
      ),
      (
        LanSyncService.syncIncludeMaintenanceFormsKey,
        'Bakim gecmisi',
        'Bakim gecmisi ve onceki bakim formlari mobile gitsin.',
        Icons.fact_check,
      ),
      (
        LanSyncService.syncIncludeFaultTicketsKey,
        'Ariza kayitlari',
        'Desktoptan teknisyene gonderilen ariza kayitlari insin.',
        Icons.build_circle,
      ),
      (
        LanSyncService.syncIncludeExpensesKey,
        'Masraf ve raporlar',
        'Masraf raporlari teknisyen hiyerarsisi ile tasinsin.',
        Icons.receipt_long,
      ),
      (
        LanSyncService.syncIncludeStocksKey,
        'Stok kartlari',
        'Desktop stok kartlari mobile taninabilir liste olarak insin.',
        Icons.inventory_2,
      ),
      (
        LanSyncService.syncIncludeAssignmentsKey,
        'Atama kurallari',
        'Teknik servis atama ve cihaz yetki iliskileri mobile gitsin.',
        Icons.assignment_ind,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(
              icon: Icons.tune,
              title: 'Telefona Inecek Ilk Veriler',
              subtitle:
                  'Yeni baglanan telefona nelerin indirilecegini buradan sec.',
              color: Colors.indigo,
            ),
            const SizedBox(height: 12),
            ...options.map(
              (option) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: autoSync.syncProfile[option.$1] ?? true,
                onChanged: (value) =>
                    autoSync.setSyncProfileOption(option.$1, value),
                secondary: Icon(option.$4, color: Colors.indigo),
                title: Text(option.$2),
                subtitle: Text(option.$3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPanelCard({
    required Widget child,
    required Color accent,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSoftMessageCard({
    required IconData icon,
    required String message,
    required Color accent,
  }) {
    return _buildPanelCard(
      accent: accent,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final hasError = _statusMessage!.contains('basarisiz') ||
        _statusMessage!.contains('baslatilamadi');
    return _buildSoftMessageCard(
      icon: hasError ? Icons.error_outline : Icons.info_outline,
      message: _statusMessage!,
      accent: hasError ? Colors.red : Colors.blue,
    );
  }

  Widget _buildAutoSyncStatusCard(LanAutoSyncService autoSync) {
    return _buildSoftMessageCard(
      icon: autoSync.isSyncing ? Icons.sync : Icons.sync_alt,
      message: autoSync.lastMessage!,
      accent: autoSync.isSyncing ? Colors.orange : Colors.green,
    );
  }

  Widget _buildResultCard(LanSyncResult result) {
    final tone = _syncResultTone(result);
    final rows = [
      ('Firma', result.companyInfoAdded),
      ('Musteri', result.customersAdded),
      ('Cihaz', result.devicesAdded),
      ('Servis Formu', result.serviceFormsAdded),
      ('Bakim Formu', result.maintenanceFormsAdded),
      ('Ariza Kaydi', result.faultTicketsAdded),
      ('Masraf', result.expensesAdded),
      ('Masraf Raporu', result.expenseReportsAdded),
      ('Stok', result.stocksAdded),
      ('Güncellenen', result.recordsUpdated),
      ('Atlanan', result.skipped),
    ];
    return _buildPanelCard(
      accent: const Color(0xFF1565C0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(
              icon: tone.$1,
              title: 'Son Veri Ozeti',
              subtitle: _resultHeadline(result),
              color: tone.$2,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tone.$2.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tone.$2.withValues(alpha: 0.14)),
              ),
              child: Row(
                children: [
                  Icon(tone.$1, color: tone.$2),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _resultActionText(result),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: rows
                  .map(
                    (row) => Chip(
                      label: Text('${row.$1}: ${row.$2}'),
                      avatar: const Icon(Icons.check, size: 18),
                    ),
                  )
                  .toList(),
            ),
            if (result.warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Dikkat gerektirenler',
                style: TextStyle(
                  color: Colors.orange.shade900,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              ...result.warnings.take(5).map(
                    (warning) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        warning,
                        style: TextStyle(color: Colors.orange.shade800),
                      ),
                    ),
                  ),
              if (result.warnings.length > 5)
                Text(
                  '+${result.warnings.length - 5} uyari daha var.',
                  style: TextStyle(color: Colors.orange.shade900),
                ),
            ],
          ],
        ),
      ),
    );
  }

  (IconData, Color) _syncResultTone(LanSyncResult result) {
    if (result.warnings.isNotEmpty) {
      return (Icons.warning_amber_outlined, Colors.orange);
    }
    if (result.totalAdded > 0 || result.recordsUpdated > 0) {
      return (Icons.check_circle_outline, Colors.green);
    }
    return (Icons.info_outline, Colors.blueGrey);
  }

  String _resultHeadline(LanSyncResult result) {
    if (result.totalAdded == 0 &&
        result.recordsUpdated == 0 &&
        result.skipped == 0) {
      return 'Senkron tamamlandi, aktarilacak yeni kayit bulunmadi.';
    }
    final parts = <String>[];
    if (result.totalAdded > 0) {
      parts.add('${result.totalAdded} kayit eklendi');
    }
    if (result.recordsUpdated > 0) {
      parts.add('${result.recordsUpdated} kayıt güncellendi');
    }
    if (result.skipped > 0) {
      parts.add('${result.skipped} kayit zaten vardi/atlandi');
    }
    if (result.warnings.isNotEmpty) {
      parts.add('${result.warnings.length} uyari var');
    }
    return 'Senkron tamamlandi: ${parts.join(', ')}.';
  }

  String _resultActionText(LanSyncResult result) {
    if (result.warnings.isNotEmpty) {
      return 'Veri alindi; uyarili kayitlari kontrol etmek icin asagidaki notlari incele.';
    }
    if (result.totalAdded > 0 || result.recordsUpdated > 0) {
      return 'Yeni ve güncellenen veriler merkeze işlendi. İlgili operasyon ekranlarında görünür.';
    }
    if (result.skipped > 0) {
      return 'Tekrarlanan kayitlar atlandi; mevcut veriler korunmus oldu.';
    }
    return 'Merkez guncel gorunuyor.';
  }
}

class _StatItem {
  final String label;
  final int value;
  final IconData icon;

  const _StatItem(this.label, this.value, this.icon);
}

class _CenterOpsSnapshot {
  final int pendingAccessRequests;
  final int pendingReviewItems;
  final int localIpCount;
  final int assignedDeviceCount;
  final int openFaultCount;

  const _CenterOpsSnapshot({
    required this.pendingAccessRequests,
    required this.pendingReviewItems,
    required this.localIpCount,
    required this.assignedDeviceCount,
    required this.openFaultCount,
  });
}

class _StockMergeSuggestion {
  final Stock imported;
  final Stock candidate;
  final String reason;

  const _StockMergeSuggestion({
    required this.imported,
    required this.candidate,
    required this.reason,
  });
}
