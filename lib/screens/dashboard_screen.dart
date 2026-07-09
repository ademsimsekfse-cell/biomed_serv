import 'package:biomed_serv/providers/dashboard_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analiz & Raporlama'),
      ),
      body: Consumer<DashboardProvider>(
        builder: (context, provider, child) {
          final hasData = provider.monthlyServiceCounts.isNotEmpty ||
              provider.monthlyMaintenanceCounts.isNotEmpty;

          if (!hasData) {
            return const Center(child: Text('Grafik için yeterli veri bulunmuyor.'));
          }

          // Servis grafik verilerini oluştur
          final serviceBarGroups = provider.monthlyServiceCounts.entries.toList()
            ..sort((a, b) {
              // Yıl ve aya göre sırala
              if (a.key.year != b.key.year) return a.key.year.compareTo(b.key.year);
              return a.key.month.compareTo(b.key.month);
            })
            ..asMap().entries.map((entry) {
              final index = entry.key;
              final yearMonth = entry.value.key;
              final count = entry.value.value.toDouble();
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: count,
                    color: Colors.lightBlueAccent,
                    width: 16,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              );
            }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // İstatistik Kartları
                _buildStatsCards(provider),
                const SizedBox(height: 24),

                // Servis Formları Grafiği
                if (provider.monthlyServiceCounts.isNotEmpty) ...[
                  const Text(
                    'Son 6 Aydaki Servis Formu Sayıları',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 250,
                    child: _buildServiceChart(provider),
                  ),
                  const SizedBox(height: 24),
                ],

                // Bakım Formları Grafiği
                if (provider.monthlyMaintenanceCounts.isNotEmpty) ...[
                  const Text(
                    'Son 6 Aydaki Bakım Formu Sayıları',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 250,
                    child: _buildMaintenanceChart(provider),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsCards(DashboardProvider provider) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Toplam Servis',
            provider.totalServices.toString(),
            Icons.build,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Toplam Bakım',
            provider.totalMaintenances.toString(),
            Icons.handyman,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Toplam İşlem',
            (provider.totalServices + provider.totalMaintenances).toString(),
            Icons.assignment,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceChart(DashboardProvider provider) {
    final sortedEntries = provider.monthlyServiceCounts.entries.toList()
      ..sort((a, b) {
        if (a.key.year != b.key.year) return a.key.year.compareTo(b.key.year);
        return a.key.month.compareTo(b.key.month);
      });

    final barGroups = sortedEntries.asMap().entries.map((entry) {
      final index = entry.key;
      final count = entry.value.value.toDouble();
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: count,
            color: Colors.lightBlueAccent,
            width: 20,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (sortedEntries.map((e) => e.value).maxOrNull ?? 0) * 1.2,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final index = value.toInt();
                if (index >= 0 && index < sortedEntries.length) {
                  final yearMonth = sortedEntries[index].key;
                  final monthName = DateFormat.MMM('tr')
                      .format(DateTime(yearMonth.year, yearMonth.month));
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(monthName, style: const TextStyle(fontSize: 10)),
                  );
                }
                return const SizedBox();
              },
              reservedSize: 38,
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 28),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
      ),
    );
  }

  Widget _buildMaintenanceChart(DashboardProvider provider) {
    final sortedEntries = provider.monthlyMaintenanceCounts.entries.toList()
      ..sort((a, b) {
        if (a.key.year != b.key.year) return a.key.year.compareTo(b.key.year);
        return a.key.month.compareTo(b.key.month);
      });

    final barGroups = sortedEntries.asMap().entries.map((entry) {
      final index = entry.key;
      final count = entry.value.value.toDouble();
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: count,
            color: Colors.greenAccent,
            width: 20,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (sortedEntries.map((e) => e.value).maxOrNull ?? 0) * 1.2,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final index = value.toInt();
                if (index >= 0 && index < sortedEntries.length) {
                  final yearMonth = sortedEntries[index].key;
                  final monthName = DateFormat.MMM('tr')
                      .format(DateTime(yearMonth.year, yearMonth.month));
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(monthName, style: const TextStyle(fontSize: 10)),
                  );
                }
                return const SizedBox();
              },
              reservedSize: 38,
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 28),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
      ),
    );
  }
}

extension IterableExtension<T extends num> on Iterable<T> {
  T? get maxOrNull => isEmpty ? null : reduce((a, b) => a > b ? a : b);
}
