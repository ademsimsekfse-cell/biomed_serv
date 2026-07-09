import 'package:biomed_serv/models/device.dart';
import 'package:biomed_serv/providers/dashboard_provider.dart'
    show DashboardProvider, YearMonth;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Gelişmiş Dashboard Ekranı
/// Pie Chart, Bar Chart, İstatistik Kartları ve Bakım Uyarıları
class DashboardScreenV2 extends StatelessWidget {
  const DashboardScreenV2({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Genel Bakış'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Dashboard'ı yenile
            },
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: Consumer<DashboardProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // === ÖZET KARTLARI ===
                _buildSummaryCards(provider),
                const SizedBox(height: 24),

                // === CİHAZ SAHİPLİK DAĞILIMI (PIE CHART) ===
                _buildOwnershipChart(provider),
                const SizedBox(height: 24),

                // === AYLIK SERVİS/BAKIM TRENDİ (BAR CHART) ===
                _buildActivityChart(provider),
                const SizedBox(height: 24),

                // === MASRAF ÖZETİ ===
                _buildExpenseSummary(provider),
                const SizedBox(height: 24),

                // === BAKIM UYARILARI ===
                _buildMaintenanceAlerts(),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 📊 Özet Kartları
  Widget _buildSummaryCards(DashboardProvider provider) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.devices,
                title: 'Toplam Cihaz',
                value: '${provider.totalDevices}',
                color: Colors.blue,
                subtitle:
                    '${provider.ownershipDistribution[OwnershipStatus.sold] ?? 0} SOLD | '
                    '${provider.ownershipDistribution[OwnershipStatus.rented] ?? 0} RENT',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.build,
                title: 'Servis/Bakım',
                value: '${provider.totalServices + provider.totalMaintenances}',
                color: Colors.orange,
                subtitle:
                    '${provider.totalServices} servis | ${provider.totalMaintenances} bakım',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.payments,
                title: 'Tahsilat',
                value:
                    '₺${NumberFormat('#,##0.00', 'tr_TR').format(provider.totalCollectedAmount)}',
                color: Colors.green,
                subtitle: '${provider.pendingExpenseCount} bekleyen masraf',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.trending_up,
                title: 'Bu Ay',
                value: _getCurrentMonthTotal(provider),
                color: Colors.purple,
                subtitle: 'işlem sayısı',
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getCurrentMonthTotal(DashboardProvider provider) {
    final now = DateTime.now();
    final currentMonth = YearMonth(now.year, now.month);
    final services = provider.monthlyServiceCounts[currentMonth] ?? 0;
    final maintenances = provider.monthlyMaintenanceCounts[currentMonth] ?? 0;
    return '${services + maintenances}';
  }

  /// 📈 İstatistik Kartı
  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required String subtitle,
  }) {
    return Card(
      elevation: 4,
      shadowColor: color.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              color.withOpacity(0.05),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🥧 Sahiplik Dağılımı (Pie Chart)
  Widget _buildOwnershipChart(DashboardProvider provider) {
    final soldCount = provider.ownershipDistribution[OwnershipStatus.sold] ?? 0;
    final rentCount =
        provider.ownershipDistribution[OwnershipStatus.rented] ?? 0;
    final total = soldCount + rentCount;

    if (total == 0) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart, color: Colors.deepPurple.shade700),
                const SizedBox(width: 8),
                Text(
                  'Cihaz Sahiplik Dağılımı',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: [
                    // SOLD bölümü
                    PieChartSectionData(
                      value: soldCount.toDouble(),
                      title: soldCount > 0 ? '$soldCount\nSOLD' : '',
                      color: Colors.green,
                      radius: 70,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    // RENT bölümü
                    PieChartSectionData(
                      value: rentCount.toDouble(),
                      title: rentCount > 0 ? '$rentCount\nRENT' : '',
                      color: Colors.orange,
                      radius: 70,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('SOLD', Colors.green, soldCount, total),
                const SizedBox(width: 24),
                _buildLegendItem('RENT', Colors.orange, rentCount, total),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Toplam: $total cihaz',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, int count, int total) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              '${(total > 0 ? (count / total * 100) : 0).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 📊 Aylık Aktivite (Bar Chart)
  Widget _buildActivityChart(DashboardProvider provider) {
    final hasServiceData = provider.monthlyServiceCounts.isNotEmpty;
    final hasMaintenanceData = provider.monthlyMaintenanceCounts.isNotEmpty;

    if (!hasServiceData && !hasMaintenanceData) {
      return const SizedBox.shrink();
    }

    // Tüm ayları birleştir ve sırala
    final allMonths = <YearMonth>{};
    allMonths.addAll(provider.monthlyServiceCounts.keys);
    allMonths.addAll(provider.monthlyMaintenanceCounts.keys);
    final sortedMonths = allMonths.toList()
      ..sort((a, b) {
        if (a.year != b.year) return a.year.compareTo(b.year);
        return a.month.compareTo(b.month);
      });

    if (sortedMonths.isEmpty) return const SizedBox.shrink();

    final maxY = _calculateMaxY(provider, sortedMonths);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Aylık Servis/Bakım Trendi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Son 6 ayın aktivite grafiği',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY * 1.2,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: Colors.blueGrey.shade800,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final month = sortedMonths[group.x.toInt()];
                        final monthName = DateFormat.MMM('tr')
                            .format(DateTime(month.year, month.month));
                        return BarTooltipItem(
                          '$monthName\n${rod.toY.toInt()} işlem',
                          const TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < sortedMonths.length) {
                            final month = sortedMonths[index];
                            final monthName = DateFormat.MMM('tr')
                                .format(DateTime(month.year, month.month));
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              child: Text(
                                monthName,
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                        reservedSize: 38,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox();
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  barGroups: sortedMonths.asMap().entries.map((entry) {
                    final index = entry.key;
                    final month = entry.value;
                    final serviceCount =
                        provider.monthlyServiceCounts[month] ?? 0;
                    final maintenanceCount =
                        provider.monthlyMaintenanceCounts[month] ?? 0;

                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        // Servis barı
                        if (serviceCount > 0)
                          BarChartRodData(
                            toY: serviceCount.toDouble(),
                            color: Colors.lightBlueAccent,
                            width: 12,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        // Bakım barı
                        if (maintenanceCount > 0)
                          BarChartRodData(
                            toY: maintenanceCount.toDouble(),
                            color: Colors.greenAccent,
                            width: 12,
                            borderRadius: BorderRadius.circular(4),
                          ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildChartLegendItem('Servis', Colors.lightBlueAccent),
                const SizedBox(width: 16),
                _buildChartLegendItem('Bakım', Colors.greenAccent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _calculateMaxY(DashboardProvider provider, List<YearMonth> months) {
    int max = 0;
    for (final month in months) {
      final serviceCount = provider.monthlyServiceCounts[month] ?? 0;
      final maintenanceCount = provider.monthlyMaintenanceCounts[month] ?? 0;
      final total = serviceCount + maintenanceCount;
      if (total > max) max = total;
    }
    return max.toDouble();
  }

  Widget _buildChartLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  /// 💰 Masraf Özeti
  Widget _buildExpenseSummary(DashboardProvider provider) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet,
                    color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text(
                  'Finansal Özet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildExpenseItem(
                    'Tahsil Edildi',
                    '₺${NumberFormat('#,##0.00', 'tr_TR').format(provider.totalCollectedAmount)}',
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildExpenseItem(
                    'Bekleyen',
                    '${provider.pendingExpenseCount} masraf',
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  /// ⚠️ Bakım Uyarıları
  Widget _buildMaintenanceAlerts() {
    final alerts = <_MaintenanceAlert>[];

    if (alerts.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  'Yaklaşan Bakımlar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${alerts.length} adet',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...alerts.map((alert) => _buildAlertItem(alert)),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertItem(_MaintenanceAlert alert) {
    final isUrgent = alert.daysLeft <= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUrgent ? Colors.red.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isUrgent ? Colors.red.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isUrgent ? Icons.warning : Icons.info,
            color: isUrgent ? Colors.red : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.deviceName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${alert.type} • ${alert.daysLeft} gün kaldı',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isUrgent ? Colors.red : Colors.orange,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isUrgent ? 'ACİL' : 'YAKLAŞIYOR',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bakım Uyarısı Modeli
class _MaintenanceAlert {
  final String deviceName;
  final int daysLeft;
  final String type;
  final String priority;

  _MaintenanceAlert({
    required this.deviceName,
    required this.daysLeft,
    required this.type,
    required this.priority,
  });
}

// YearMonth sınıfı DashboardProvider'dan import edilir
