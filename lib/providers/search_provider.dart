import 'package:biomed_serv/models/customer.dart';
import 'package:biomed_serv/models/device.dart';
import 'package:biomed_serv/models/fault_ticket.dart';
import 'package:biomed_serv/services/database_service.dart';
import 'package:flutter/foundation.dart';

/// Arama sonucu modeli
class SearchResult {
  final String id;
  final String title;
  final String subtitle;
  final String type;
  final dynamic data;
  final DateTime? date;

  SearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    this.data,
    this.date,
  });
}

/// Arama sağlayıcısı
class SearchProvider with ChangeNotifier {
  final DatabaseService _dbService;

  SearchProvider(this._dbService);

  List<SearchResult> _results = [];
  List<SearchResult> get results => _results;

  String _lastQuery = '';
  String get lastQuery => _lastQuery;

  bool _isSearching = false;
  bool get isSearching => _isSearching;

  // Pagination state
  int _currentPage = 0;
  static const int _pageSize = 50;
  bool _hasMoreData = true;
  bool get hasMoreData => _hasMoreData;

  /// Genel arama (Cihaz, Müşteri, Formlar, Arıza Kayıtları)
  Future<void> search(String query, {bool loadMore = false}) async {
    if (query.isEmpty && !loadMore) {
      _results = [];
      _lastQuery = '';
      _currentPage = 0;
      _hasMoreData = true;
      notifyListeners();
      return;
    }

    _isSearching = true;
    if (!loadMore) {
      _lastQuery = query;
      _currentPage = 0;
      _hasMoreData = true;
    }
    notifyListeners();

    final lowerQuery = query.toLowerCase();
    final results = <SearchResult>[];

    // Cihaz ara
    final deviceResults = _searchDevices(lowerQuery);
    results.addAll(deviceResults);

    // Müşteri ara
    final customerResults = _searchCustomers(lowerQuery);
    results.addAll(customerResults);

    // Servis formları ara
    final serviceResults = _searchServiceForms(lowerQuery);
    results.addAll(serviceResults);

    // Bakım formları ara
    final maintenanceResults = _searchMaintenanceForms(lowerQuery);
    results.addAll(maintenanceResults);

    // Arıza kayıtları ara
    final faultResults = _searchFaultTickets(lowerQuery);
    results.addAll(faultResults);

    // Tarihe göre sırala (en yeni en üstte)
    results.sort((a, b) {
      if (a.date == null && b.date == null) return 0;
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return b.date!.compareTo(a.date!);
    });

    // Pagination uygula
    final startIndex = loadMore ? _currentPage * _pageSize : 0;
    final endIndex = startIndex + _pageSize;
    
    if (endIndex >= results.length) {
      _hasMoreData = false;
    }

    final paginatedResults = results.sublist(
      0,
      endIndex > results.length ? results.length : endIndex,
    );

    if (loadMore) {
      _results.addAll(paginatedResults.skip(_results.length));
    } else {
      _results = paginatedResults;
    }
    
    _currentPage++;
    _isSearching = false;
    notifyListeners();
  }

  /// Daha fazla sonuç yükle
  Future<void> loadMore() async {
    if (_hasMoreData && !_isSearching && _lastQuery.isNotEmpty) {
      await search(_lastQuery, loadMore: true);
    }
  }

  List<SearchResult> _searchDevices(String query) {
    final results = <SearchResult>[];
    final devices = _dbService.devicesBox.values;

    for (final device in devices) {
      final match = device.name.toLowerCase().contains(query) ||
          device.brand.toLowerCase().contains(query) ||
          device.model.toLowerCase().contains(query) ||
          device.serialNumber.toLowerCase().contains(query) ||
          (device.barcode?.toLowerCase().contains(query) ?? false);

      if (match) {
        results.add(SearchResult(
          id: 'device_${device.key}',
          title: device.name,
          subtitle: '${device.brand} ${device.model}',
          type: 'Cihaz',
          data: device,
        ));
      }
    }

    return results;
  }

  List<SearchResult> _searchCustomers(String query) {
    final results = <SearchResult>[];
    final customers = _dbService.customersBox.values;

    for (final customer in customers) {
      final match = customer.name.toLowerCase().contains(query) ||
          customer.address.toLowerCase().contains(query) ||
          customer.phone.toLowerCase().contains(query) ||
          customer.authorizedPerson.toLowerCase().contains(query) ||
          (customer.email?.toLowerCase().contains(query) ?? false) ||
          (customer.vergiNo?.toLowerCase().contains(query) ?? false);

      if (match) {
        results.add(SearchResult(
          id: 'customer_${customer.key}',
          title: customer.name,
          subtitle: customer.address,
          type: 'Kurum',
          data: customer,
        ));
      }
    }

    return results;
  }

  List<SearchResult> _searchServiceForms(String query) {
    final results = <SearchResult>[];
    final forms = _dbService.serviceFormsBox.values;

    for (final form in forms) {
      final customer = form.customer as Customer?;
      final device = form.device as Device?;

      final match = form.formNumber.toLowerCase().contains(query) ||
          (form.problemDescription?.toLowerCase().contains(query) ?? false) ||
          customer?.name.toLowerCase().contains(query) == true ||
          device?.name.toLowerCase().contains(query) == true;

      if (match) {
        results.add(SearchResult(
          id: 'service_${form.key}',
          title: 'Servis #${form.formNumber}',
          subtitle: '${customer?.name ?? ""} - ${device?.name ?? ""}',
          type: 'Servis Formu',
          data: form,
          date: form.createdAt,
        ));
      }
    }

    return results;
  }

  List<SearchResult> _searchMaintenanceForms(String query) {
    final results = <SearchResult>[];
    final forms = _dbService.maintenanceFormsBox.values;

    for (final form in forms) {
      final customer = form.customer as Customer?;
      final device = form.device as Device?;

      final match = form.formNumber.toLowerCase().contains(query) ||
          (form.notes?.toLowerCase().contains(query) ?? false) ||
          customer?.name.toLowerCase().contains(query) == true ||
          device?.name.toLowerCase().contains(query) == true;

      if (match) {
        results.add(SearchResult(
          id: 'maintenance_${form.key}',
          title: 'Bakım #${form.formNumber}',
          subtitle: '${customer?.name ?? ""} - ${device?.name ?? ""}',
          type: 'Bakım Formu',
          data: form,
          date: form.createdAt,
        ));
      }
    }

    return results;
  }

  List<SearchResult> _searchFaultTickets(String query) {
    final results = <SearchResult>[];
    final tickets = _dbService.faultTicketsBox.values;

    for (final ticket in tickets) {
      final match = ticket.ticketNumber.toLowerCase().contains(query) ||
          ticket.problemDescription.toLowerCase().contains(query) ||
          ticket.customer.name.toLowerCase().contains(query) ||
          ticket.device.name.toLowerCase().contains(query) ||
          (ticket.technicianName?.toLowerCase().contains(query) ?? false);

      if (match) {
        results.add(SearchResult(
          id: 'fault_${ticket.key}',
          title: 'Arıza #${ticket.ticketNumber}',
          subtitle: '${ticket.customer.name} - ${ticket.device.name}',
          type: 'Arıza Kaydı',
          data: ticket,
          date: ticket.reportDateTime,
        ));
      }
    }

    return results;
  }

  void clearResults() {
    _results = [];
    _lastQuery = '';
    notifyListeners();
  }
}
