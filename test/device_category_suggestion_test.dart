import 'package:biomed_serv/models/device.dart';
import 'package:biomed_serv/services/device_category_suggestion_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = DeviceCategorySuggestionService();
  final devices = [
    Device(
      name: 'Biyokimya Analizörü',
      brand: 'Acme',
      model: 'AX-500',
      serialNumber: 'AX5-2025-001',
      deviceCategory: 'Laboratuvar',
    ),
    Device(
      name: 'Ultrason',
      brand: 'Medi',
      model: 'US-Pro',
      serialNumber: 'USP-99100',
      deviceCategory: 'Görüntüleme',
    ),
  ];

  test('same model recommends the learned category first', () {
    final suggestions = service.suggest(
      devices: devices,
      brand: 'Acme',
      model: 'AX-500',
      serialNumber: 'NEW-100',
    );

    expect(suggestions, isNotEmpty);
    expect(suggestions.first.category, 'Laboratuvar');
    expect(suggestions.first.reason, contains('Aynı cihaz modeli'));
  });

  test('matching serial prefix recommends category', () {
    final suggestions = service.suggest(
      devices: devices,
      serialNumber: 'USP-99222',
    );

    expect(suggestions, isNotEmpty);
    expect(suggestions.first.category, 'Görüntüleme');
    expect(suggestions.first.reason, contains('seri numarası'));
  });

  test('unrelated device does not produce a weak guess', () {
    final suggestions = service.suggest(
      devices: devices,
      brand: 'Başka',
      model: 'ZZ-10',
      serialNumber: 'Q-1',
    );

    expect(suggestions, isEmpty);
  });
}
