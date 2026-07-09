import 'package:biomed_serv/models/device.dart';
import 'package:hive/hive.dart';

class DeviceCategorySuggestion {
  final String category;
  final int score;
  final String reason;

  const DeviceCategorySuggestion({
    required this.category,
    required this.score,
    required this.reason,
  });
}

class DeviceCategorySuggestionService {
  static const String _prefsBoxName = 'app_preferences';
  static const String _categoriesKey = 'remembered_device_categories';

  Future<List<String>> knownCategories(Iterable<Device> devices) async {
    final categories = <String>{
      ...devices
          .map((device) => device.deviceCategory?.trim() ?? '')
          .where((category) => category.isNotEmpty),
    };
    final prefs = await Hive.openBox(_prefsBoxName);
    final remembered =
        prefs.get(_categoriesKey) as List<dynamic>? ?? const <dynamic>[];
    categories.addAll(
      remembered.map((item) => item.toString().trim()).where(
            (category) => category.isNotEmpty,
          ),
    );
    return categories.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  Future<void> rememberCategory(String category) async {
    final cleanCategory = category.trim();
    if (cleanCategory.isEmpty) return;
    final prefs = await Hive.openBox(_prefsBoxName);
    final current =
        prefs.get(_categoriesKey) as List<dynamic>? ?? const <dynamic>[];
    final categories = current.map((item) => item.toString()).toList();
    if (!categories.any(
      (item) => _normalize(item) == _normalize(cleanCategory),
    )) {
      categories.add(cleanCategory);
      categories.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      await prefs.put(_categoriesKey, categories);
    }
  }

  List<DeviceCategorySuggestion> suggest({
    required Iterable<Device> devices,
    String name = '',
    String brand = '',
    String model = '',
    String serialNumber = '',
  }) {
    final inputName = _normalize(name);
    final inputBrand = _normalize(brand);
    final inputModel = _normalize(model);
    final inputSerial = _normalizeSerial(serialNumber);
    final bestByCategory = <String, DeviceCategorySuggestion>{};

    for (final device in devices) {
      final category = device.deviceCategory?.trim() ?? '';
      if (category.isEmpty) continue;

      var score = 0;
      var reason = '';
      final deviceModel = _normalize(device.model);
      final deviceBrand = _normalize(device.brand);
      final deviceName = _normalize(device.name);
      final deviceSerial = _normalizeSerial(device.serialNumber);

      if (inputModel.isNotEmpty && inputModel == deviceModel) {
        score += 70;
        reason = 'Aynı cihaz modeli';
      } else if (_isSimilar(inputModel, deviceModel)) {
        score += 42;
        reason = 'Benzer cihaz modeli';
      }

      if (inputBrand.isNotEmpty && inputBrand == deviceBrand) {
        score += 18;
        reason = reason.isEmpty ? 'Aynı marka' : reason;
      }
      if (inputName.isNotEmpty && inputName == deviceName) {
        score += 16;
        reason = reason.isEmpty ? 'Aynı cihaz adı' : reason;
      }

      final serialPrefix = _commonPrefixLength(inputSerial, deviceSerial);
      if (serialPrefix >= 4) {
        score += 28 + (serialPrefix.clamp(4, 8) - 4) * 4;
        reason = reason.isEmpty
            ? 'Benzer seri numarası başlangıcı'
            : '$reason ve seri numarası';
      }

      if (score < 28) continue;
      final key = _normalize(category);
      final candidate = DeviceCategorySuggestion(
        category: category,
        score: score,
        reason: reason,
      );
      final current = bestByCategory[key];
      if (current == null || candidate.score > current.score) {
        bestByCategory[key] = candidate;
      }
    }

    final results = bestByCategory.values.toList()
      ..sort((a, b) {
        final scoreComparison = b.score.compareTo(a.score);
        return scoreComparison != 0
            ? scoreComparison
            : a.category.compareTo(b.category);
      });
    return results.take(3).toList();
  }

  bool _isSimilar(String first, String second) {
    if (first.length < 3 || second.length < 3) return false;
    return first.startsWith(second) ||
        second.startsWith(first) ||
        _commonPrefixLength(first, second) >= 4;
  }

  int _commonPrefixLength(String first, String second) {
    final limit = first.length < second.length ? first.length : second.length;
    var length = 0;
    while (length < limit && first[length] == second[length]) {
      length++;
    }
    return length;
  }

  String _normalize(String value) => value.trim().toLowerCase();

  String _normalizeSerial(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }
}
