import 'package:biomed_serv/providers/search_provider.dart';
import 'package:biomed_serv/screens/customer_management_screen.dart';
import 'package:biomed_serv/screens/device_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Global Arama Ekranı
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  
  // Filtre state'leri
  final Set<String> _selectedTypes = {'all'};
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showFilters = false;

  final List<Map<String, dynamic>> _filterOptions = [
    {'id': 'all', 'label': 'Tümü', 'icon': Icons.all_inclusive},
    {'id': 'device', 'label': 'Cihaz', 'icon': Icons.devices},
    {'id': 'customer', 'label': 'Kurum', 'icon': Icons.business},
    {'id': 'service', 'label': 'Servis', 'icon': Icons.build},
    {'id': 'maintenance', 'label': 'Bakım', 'icon': Icons.handyman},
    {'id': 'fault', 'label': 'Arıza', 'icon': Icons.error_outline},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: 'Cihaz, kurum veya form ara...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white),
                    onPressed: () {
                      _searchController.clear();
                      Provider.of<SearchProvider>(context, listen: false)
                          .clearResults();
                    },
                  )
                : null,
          ),
          style: const TextStyle(color: Colors.white, fontSize: 18),
          onChanged: (value) {
            // Debounce ile arama
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted && _searchController.text == value) {
                Provider.of<SearchProvider>(context, listen: false)
                    .search(value);
              }
            });
          },
        ),
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list),
            onPressed: () {
              setState(() => _showFilters = !_showFilters);
            },
            tooltip: 'Filtreler',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _performSearch(),
          ),
        ],
        bottom: _showFilters ? _buildFilterBar() : null,
      ),
      body: Column(
        children: [
          if (_showFilters) _buildAdvancedFilters(),
          Expanded(
            child: Consumer<SearchProvider>(
              builder: (context, searchProvider, child) {
                if (searchProvider.isSearching) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (searchProvider.lastQuery.isEmpty && _searchController.text.isEmpty) {
                  return _buildInitialView();
                }

                final filteredResults = _filterResults(searchProvider.results);

                if (filteredResults.isEmpty) {
                  return _buildEmptyView(searchProvider.lastQuery);
                }

                return _buildResultsList(filteredResults);
              },
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildFilterBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(50),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
        ),
        child: Row(
          children: [
            Text(
              'Filtreler aktif',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear, size: 18),
              label: const Text('Temizle'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tip Filtreleri
          const Text(
            'Tip',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _filterOptions.map((option) {
              final isSelected = _selectedTypes.contains(option['id']);
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                child: FilterChip(
                  selected: isSelected,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        option['icon'],
                        size: 16,
                        color: isSelected ? const Color(0xFF1565C0) : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        option['label'],
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF1565C0) : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (option['id'] == 'all') {
                        if (selected) {
                          _selectedTypes.clear();
                          _selectedTypes.add('all');
                        }
                      } else {
                        if (selected) {
                          _selectedTypes.remove('all');
                          _selectedTypes.add(option['id']);
                        } else {
                          _selectedTypes.remove(option['id']);
                          if (_selectedTypes.isEmpty) {
                            _selectedTypes.add('all');
                          }
                        }
                      }
                    });
                    _performSearch();
                  },
                  selectedColor: const Color(0xFFE3F2FD),
                  backgroundColor: Colors.white,
                  checkmarkColor: const Color(0xFF1565C0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF64B5F6) : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  elevation: isSelected ? 3 : 1,
                  shadowColor: isSelected ? const Color(0xFF64B5F6).withOpacity(0.3) : Colors.grey.withOpacity(0.2),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          
          // Tarih Filtreleri
          const Text(
            'Tarih Aralığı',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          _startDate != null
                              ? DateFormat('dd.MM.yyyy').format(_startDate!)
                              : 'Başlangıç',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('-'),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          _endDate != null
                              ? DateFormat('dd.MM.yyyy').format(_endDate!)
                              : 'Bitiş',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null) {
      setState(() {
        if (isStart) {
          _startDate = date;
        } else {
          _endDate = date;
        }
      });
      _performSearch();
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedTypes.clear();
      _selectedTypes.add('all');
      _startDate = null;
      _endDate = null;
    });
    _performSearch();
  }

  void _performSearch() {
    Provider.of<SearchProvider>(context, listen: false)
        .search(_searchController.text);
  }

  List<dynamic> _filterResults(List<dynamic> results) {
    if (_selectedTypes.contains('all') && _startDate == null && _endDate == null) {
      return results;
    }

    return results.where((result) {
      // Tip filtresi
      if (!_selectedTypes.contains('all')) {
        final typeMap = {
          'Cihaz': 'device',
          'Kurum': 'customer',
          'Servis Formu': 'service',
          'Bakım Formu': 'maintenance',
          'Arıza Kaydı': 'fault',
        };
        final resultType = typeMap[result.type] ?? '';
        if (!_selectedTypes.contains(resultType)) {
          return false;
        }
      }

      // Tarih filtresi
      if (result.date != null) {
        if (_startDate != null && result.date!.isBefore(_startDate!)) {
          return false;
        }
        if (_endDate != null) {
          final endDateWithTime = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59);
          if (result.date!.isAfter(endDateWithTime)) {
            return false;
          }
        }
      }

      return true;
    }).toList();
  }

  Widget _buildInitialView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Aramaya başlamak için yazın',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cihaz adı, marka, model, kurum adı,\nform numarası ile arama yapabilirsiniz',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 16),
          if (_selectedTypes.contains('all') == false || _startDate != null || _endDate != null)
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear),
              label: const Text('Filtreleri Temizle'),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyView(String query) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            '"$query" için sonuç bulunamadı',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Farklı bir arama terimi deneyin',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList(List<dynamic> results) {
    final dateFormat = DateFormat('dd.MM.yyyy');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        return _buildResultCard(result, dateFormat);
      },
    );
  }

  Widget _buildResultCard(dynamic result, DateFormat dateFormat) {
    IconData icon;
    Color color;

    switch (result.type) {
      case 'Cihaz':
        icon = Icons.devices;
        color = Colors.blue;
        break;
      case 'Kurum':
        icon = Icons.business;
        color = Colors.green;
        break;
      case 'Servis Formu':
        icon = Icons.build;
        color = Colors.orange;
        break;
      case 'Bakım Formu':
        icon = Icons.handyman;
        color = Colors.purple;
        break;
      default:
        icon = Icons.label;
        color = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          result.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(result.subtitle),
            if (result.date != null) ...[
              const SizedBox(height: 2),
              Text(
                dateFormat.format(result.date!),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                result.type,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        onTap: () => _onResultTap(result),
      ),
    );
  }

  void _onResultTap(dynamic result) {
    switch (result.type) {
      case 'Cihaz':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DeviceDetailScreen(device: result.data),
          ),
        );
        break;
      case 'Kurum':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CustomerManagementScreen(),
          ),
        );
        break;
      case 'Servis Formu':
        // Form detay göster (şimdilik yeni form ekranı aç)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Servis Formu #${result.data.formNumber}'),
          ),
        );
        break;
      case 'Bakım Formu':
        // Form detay göster
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bakım Formu #${result.data.formNumber}'),
          ),
        );
        break;
    }
  }
}
