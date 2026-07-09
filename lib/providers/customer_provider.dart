import 'dart:async';

import 'package:biomed_serv/models/customer.dart';
import 'package:biomed_serv/services/database_service.dart';
import 'package:biomed_serv/utils/app_exception.dart';
import 'package:biomed_serv/utils/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class CustomerProvider with ChangeNotifier {
  final DatabaseService _dbService;
  late Box<Customer> _customerBox;
  StreamSubscription<BoxEvent>? _customerSubscription;

  List<Customer> _customers = [];
  List<Customer> get customers => _customers;

  AppException? _lastError;
  AppException? get lastError => _lastError;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  CustomerProvider(this._dbService) {
    try {
      _customerBox = _dbService.customersBox;
      _customerSubscription =
          _customerBox.watch().listen((_) => _loadCustomers());
      _loadCustomers();
      AppLogger.info('CustomerProvider başlatıldı', tag: 'Provider');
    } catch (e) {
      AppLogger.error('CustomerProvider başlatma hatası',
          exception: e, tag: 'Provider');
      _lastError = DatabaseException(
        message: 'Müşteri veritabanı yüklenemedi',
        originalException: e,
      );
      rethrow;
    }
  }

  @override
  void dispose() {
    _customerSubscription?.cancel();
    super.dispose();
  }

  /// Müşterileri veritabanından yükle
  void _loadCustomers() {
    try {
      _isLoading = true;
      notifyListeners();

      _customers = _customerBox.values.toList();
      _lastError = null;

      AppLogger.info('${_customers.length} müşteri yüklendi',
          tag: 'CustomerProvider');
    } catch (e) {
      AppLogger.error('Müşteri listesi yükleme hatası',
          exception: e, tag: 'CustomerProvider');
      _lastError = DatabaseException(
        message: 'Müşteri listesi yüklenemedi',
        originalException: e,
      );
      _customers = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Yeni müşteri ekle
  Future<void> addCustomer(Customer customer) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Validation
      if (customer.name.trim().isEmpty) {
        throw ValidationException(
          message: 'Müşteri adı boş olamaz',
          code: 'EMPTY_CUSTOMER_NAME',
        );
      }

      _ensureUniqueCustomerName(customer);

      await _customerBox.add(customer);
      _loadCustomers();

      AppLogger.info('Yeni müşteri eklendi: ${customer.name}',
          tag: 'CustomerProvider');
    } catch (e) {
      AppLogger.error('Müşteri ekleme hatası',
          exception: e, tag: 'CustomerProvider');
      _lastError = DatabaseException(
        message: 'Müşteri eklenemedi: $e',
        originalException: e,
      );
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Müşteriyi güncelle
  Future<void> updateCustomer(int key, Customer customer) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Validation
      if (customer.name.trim().isEmpty) {
        throw ValidationException(
          message: 'Müşteri adı boş olamaz',
          code: 'EMPTY_CUSTOMER_NAME',
        );
      }

      _ensureUniqueCustomerName(customer, excludeKey: key);

      await _customerBox.put(key, customer);
      _loadCustomers();

      AppLogger.info('Müşteri güncellendi: ${customer.name}',
          tag: 'CustomerProvider');
    } catch (e) {
      AppLogger.error('Müşteri güncelleme hatası',
          exception: e, tag: 'CustomerProvider');
      _lastError = DatabaseException(
        message: 'Müşteri güncellenemedi: $e',
        originalException: e,
      );
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Müşteriyi sil
  Future<void> deleteCustomer(int key) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _customerBox.delete(key);
      _loadCustomers();

      AppLogger.info('Müşteri silindi (key: $key)', tag: 'CustomerProvider');
    } catch (e) {
      AppLogger.error('Müşteri silme hatası',
          exception: e, tag: 'CustomerProvider');
      _lastError = DatabaseException(
        message: 'Müşteri silinemedi: $e',
        originalException: e,
      );
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Error'u sıfırla
  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  Customer? customerWithName(String name, {int? excludeKey}) {
    final target = _normalizeName(name);
    if (target.isEmpty) return null;

    for (final customer in _customerBox.values) {
      if (excludeKey != null && customer.key == excludeKey) continue;
      if (_normalizeName(customer.name) == target) return customer;
    }
    return null;
  }

  bool isCustomerNameAvailable(String name, {int? excludeKey}) {
    return customerWithName(name, excludeKey: excludeKey) == null;
  }

  void _ensureUniqueCustomerName(Customer customer, {int? excludeKey}) {
    final existing = customerWithName(customer.name, excludeKey: excludeKey);
    if (existing == null) return;
    throw ValidationException(
      message: '"${customer.name}" adinda bir cari zaten kayitli',
      code: 'DUPLICATE_CUSTOMER_NAME',
    );
  }

  String _normalizeName(String value) => value.trim().toLowerCase();
}
