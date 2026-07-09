import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class AppUiSettingsService extends ChangeNotifier {
  static const String prefsBoxName = 'app_preferences';
  static const String menuLockedKey = 'ui_menu_locked';
  static const String menuOrderKey = 'ui_menu_order';
  static const String menuGroupsKey = 'ui_menu_groups';
  static const String quickActionOrderKey = 'ui_quick_action_order';
  static const String themeIdKey = 'ui_theme_id';

  Box? _box;
  bool _initialized = false;
  bool _menuLocked = true;
  List<String> _menuOrder = const [];
  Map<String, String> _menuGroups = const {};
  List<String> _quickActionOrder = const [];
  String _themeId = 'clinicalBlue';

  bool get initialized => _initialized;
  bool get menuLocked => _menuLocked;
  List<String> get menuOrder => List.unmodifiable(_menuOrder);
  Map<String, String> get menuGroups => Map.unmodifiable(_menuGroups);
  List<String> get quickActionOrder => List.unmodifiable(_quickActionOrder);
  String get themeId => _themeId;

  Color get seedColor {
    switch (_themeId) {
      case 'emerald':
        return const Color(0xFF0F766E);
      case 'graphite':
        return const Color(0xFF475569);
      case 'ruby':
        return const Color(0xFFBE123C);
      case 'amber':
        return const Color(0xFFB45309);
      case 'clinicalBlue':
      default:
        return const Color(0xFF1565C0);
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    _box = await Hive.openBox(prefsBoxName);
    _menuLocked = _box!.get(menuLockedKey) as bool? ?? true;
    _themeId = _box!.get(themeIdKey) as String? ?? 'clinicalBlue';
    _menuOrder = _readStringList(menuOrderKey);
    _quickActionOrder = _readStringList(quickActionOrderKey);
    _menuGroups = _readStringMap(menuGroupsKey);
    _initialized = true;
    notifyListeners();
  }

  List<String> orderedMenuIds(List<String> defaults) {
    final known = defaults.toSet();
    final ordered = _menuOrder.where(known.contains).toList();
    ordered.addAll(defaults.where((id) => !ordered.contains(id)));
    return ordered;
  }

  List<String> orderedQuickActionIds(List<String> defaults) {
    final known = defaults.toSet();
    final ordered = _quickActionOrder.where(known.contains).toList();
    ordered.addAll(defaults.where((id) => !ordered.contains(id)));
    return ordered;
  }

  String groupFor(String itemId, String defaultGroup) {
    final group = _menuGroups[itemId];
    return group == null || group.isEmpty ? defaultGroup : group;
  }

  Future<void> setMenuLocked(bool locked) async {
    await init();
    _menuLocked = locked;
    await _box!.put(menuLockedKey, locked);
    notifyListeners();
  }

  Future<void> setMenuOrder(List<String> ids) async {
    await init();
    _menuOrder = ids;
    await _box!.put(menuOrderKey, ids);
    notifyListeners();
  }

  Future<void> setQuickActionOrder(List<String> ids) async {
    await init();
    _quickActionOrder = ids;
    await _box!.put(quickActionOrderKey, ids);
    notifyListeners();
  }

  Future<void> setMenuGroup(String itemId, String groupId) async {
    await init();
    _menuGroups = {..._menuGroups, itemId: groupId};
    await _box!.put(menuGroupsKey, _menuGroups);
    notifyListeners();
  }

  Future<void> setThemeId(String themeId) async {
    await init();
    _themeId = themeId;
    await _box!.put(themeIdKey, themeId);
    notifyListeners();
  }

  Future<void> resetMenu() async {
    await init();
    _menuOrder = const [];
    _menuGroups = const {};
    await _box!.delete(menuOrderKey);
    await _box!.delete(menuGroupsKey);
    notifyListeners();
  }

  Future<void> resetQuickActions() async {
    await init();
    _quickActionOrder = const [];
    await _box!.delete(quickActionOrderKey);
    notifyListeners();
  }

  List<String> _readStringList(String key) {
    final value = _box!.get(key);
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return const [];
  }

  Map<String, String> _readStringMap(String key) {
    final value = _box!.get(key);
    if (value is Map) {
      return value.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    }
    return const {};
  }
}
