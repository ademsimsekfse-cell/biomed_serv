import 'package:biomed_serv/models/device_personel.dart';
import 'package:biomed_serv/services/database_service.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Cihaz Sorumlu Personel Provider
class DevicePersonelProvider with ChangeNotifier {
  final DatabaseService _dbService;
  late Box<DevicePersonel> _personelBox;

  List<DevicePersonel> _personels = [];
  List<DevicePersonel> get personels => _personels;

  DevicePersonelProvider(this._dbService) {
    _personelBox = _dbService.devicePersonelsBox;
    _loadPersonels();
  }

  void _loadPersonels() {
    _personels = _personelBox.values.toList();
    notifyListeners();
  }

  /// Yeni personel ekle
  Future<void> addPersonel(DevicePersonel personel) async {
    await _personelBox.add(personel);
    _loadPersonels();
  }

  List<DevicePersonel> personelsForCustomer(dynamic customer) {
    final customerKey = customer?.key;
    if (customerKey == null) return const [];

    return _personels.where((personel) {
      return belongsToCustomer(personel, customer);
    }).toList();
  }

  List<DevicePersonel> availablePersonelsForCustomer(dynamic customer) {
    final customerKey = customer?.key;
    if (customerKey == null) return const [];

    return _personels.where((personel) {
      final personelCustomerKey = personel.customer?.key;
      return personelCustomerKey == null || personelCustomerKey == customerKey;
    }).toList();
  }

  bool belongsToCustomer(DevicePersonel personel, dynamic customer) {
    final customerKey = customer?.key;
    if (customerKey == null) return false;
    return personel.customer?.key == customerKey;
  }

  DevicePersonel? findMatchingPersonel({
    required String firstName,
    required String lastName,
    String? phone,
    String? email,
    dynamic customer,
  }) {
    final normalizedFirstName = _normalizeText(firstName);
    final normalizedLastName = _normalizeText(lastName);
    final normalizedPhone = _normalizePhone(phone);
    final normalizedEmail = _normalizeText(email);

    if (normalizedFirstName.isEmpty || normalizedLastName.isEmpty) {
      return null;
    }

    for (final personel in _personels) {
      if (_normalizeText(personel.firstName) != normalizedFirstName ||
          _normalizeText(personel.lastName) != normalizedLastName) {
        continue;
      }

      if (customer?.key != null &&
          personel.customer?.key != null &&
          personel.customer?.key != customer.key) {
        continue;
      }

      final existingPhone = _normalizePhone(personel.phone);
      final existingEmail = _normalizeText(personel.email);
      final noIdentifierProvided =
          normalizedPhone.isEmpty && normalizedEmail.isEmpty;
      final phoneMatches =
          normalizedPhone.isNotEmpty && existingPhone == normalizedPhone;
      final emailMatches =
          normalizedEmail.isNotEmpty && existingEmail == normalizedEmail;

      if (phoneMatches || emailMatches || noIdentifierProvided) {
        return personel;
      }
    }

    return null;
  }

  Future<DevicePersonel> ensurePersonel(DevicePersonel personel) async {
    final existing = findMatchingPersonel(
      firstName: personel.firstName,
      lastName: personel.lastName,
      phone: personel.phone,
      email: personel.email,
      customer: personel.customer,
    );

    if (existing == null) {
      await _personelBox.add(personel);
      _loadPersonels();
      return personel;
    }

    var changed = false;
    final trimmedPhone = personel.phone?.trim();
    final trimmedEmail = personel.email?.trim();
    final trimmedTitle = personel.title?.trim();

    if ((existing.phone?.trim().isEmpty ?? true) &&
        (trimmedPhone?.isNotEmpty ?? false)) {
      existing.phone = trimmedPhone;
      changed = true;
    }
    if ((existing.email?.trim().isEmpty ?? true) &&
        (trimmedEmail?.isNotEmpty ?? false)) {
      existing.email = trimmedEmail;
      changed = true;
    }
    if ((existing.title?.trim().isEmpty ?? true) &&
        (trimmedTitle?.isNotEmpty ?? false)) {
      existing.title = trimmedTitle;
      changed = true;
    }
    if (existing.assignedDate == null) {
      existing.assignedDate = personel.assignedDate ?? DateTime.now();
      changed = true;
    }
    if (existing.customer == null && personel.customer != null) {
      existing.customer = personel.customer;
      changed = true;
    }

    if (changed) {
      await existing.save();
      _loadPersonels();
    }

    return existing;
  }

  /// Personel güncelle
  Future<void> updatePersonel(int key, DevicePersonel personel) async {
    await _personelBox.put(key, personel);
    _loadPersonels();
  }

  Future<DevicePersonel> assignPersonelToCustomer(
    DevicePersonel personel,
    dynamic customer,
  ) async {
    if (customer?.key == null) {
      throw Exception('Personel ataması için kurum seçilmelidir.');
    }

    final currentCustomerKey = personel.customer?.key;
    if (currentCustomerKey != null && currentCustomerKey != customer.key) {
      throw Exception(
        'Bu personel farklı bir kuruma bağlı. Başka kurum cihazına atanamaz.',
      );
    }

    if (currentCustomerKey == null) {
      personel.customer = customer;
      if (personel.key is int) {
        await _personelBox.put(personel.key as int, personel);
      } else {
        await _personelBox.add(personel);
      }
      _loadPersonels();
    }

    return personel;
  }

  /// Personel sil
  Future<void> deletePersonel(int key) async {
    await _personelBox.delete(key);
    _loadPersonels();
  }

  /// İsme göre ara
  List<DevicePersonel> searchPersonels(String query) {
    if (query.isEmpty) return _personels;

    final lowerQuery = query.toLowerCase();
    return _personels.where((p) {
      return p.fullName.toLowerCase().contains(lowerQuery) ||
          (p.phone?.toLowerCase().contains(lowerQuery) ?? false) ||
          (p.email?.toLowerCase().contains(lowerQuery) ?? false) ||
          (p.title?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  String _normalizeText(String? value) {
    return (value ?? '').trim().toLowerCase();
  }

  String _normalizePhone(String? value) {
    return (value ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
  }

  /// Demo personeller ekle (test için)
  Future<void> addDemoPersonels() async {
    if (_personels.isNotEmpty) return;

    final demoPersonels = [
      DevicePersonel(
        firstName: 'Ahmet',
        lastName: 'Yılmaz',
        phone: '0555 123 4567',
        email: 'ahmet.yilmaz@example.com',
        title: 'Teknik Müdür',
        assignedDate: DateTime.now(),
      ),
      DevicePersonel(
        firstName: 'Mehmet',
        lastName: 'Demir',
        phone: '0555 987 6543',
        email: 'mehmet.demir@example.com',
        title: 'Bakım Sorumlusu',
        assignedDate: DateTime.now(),
      ),
      DevicePersonel(
        firstName: 'Ayşe',
        lastName: 'Kaya',
        phone: '0555 456 7890',
        email: 'ayse.kaya@example.com',
        title: 'Saha Mühendisi',
        assignedDate: DateTime.now(),
      ),
    ];

    for (final personel in demoPersonels) {
      await _personelBox.add(personel);
    }
    _loadPersonels();
  }
}
