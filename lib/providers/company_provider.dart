import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/company_info.dart';

class CompanyProvider extends ChangeNotifier {
  static const String _boxName = 'company_info';

  Box<CompanyInfo>? _companyBox;
  StreamSubscription<BoxEvent>? _companySubscription;
  CompanyInfo? _companyInfo;

  CompanyInfo? get companyInfo => _companyInfo;
  bool get hasCompanyInfo => _companyInfo != null;
  bool get hasLogo => _companyInfo?.hasLogo ?? false;
  Box<CompanyInfo>? get companyBox => _companyBox;

  Future<void> init() async {
    if (Hive.isBoxOpen(_boxName)) {
      _companyBox = Hive.box<CompanyInfo>(_boxName);
    } else {
      await _waitForBoxOpen(maxWait: const Duration(seconds: 3));
    }

    _refreshFromBox(notify: false);
    await _companySubscription?.cancel();
    _companySubscription =
        _companyBox?.watch().listen((_) => _refreshFromBox());
    notifyListeners();
  }

  Future<void> _waitForBoxOpen({required Duration maxWait}) async {
    const checkInterval = Duration(milliseconds: 100);
    var elapsed = Duration.zero;
    while (elapsed < maxWait) {
      if (Hive.isBoxOpen(_boxName)) {
        _companyBox = Hive.box<CompanyInfo>(_boxName);
        return;
      }
      await Future<void>.delayed(checkInterval);
      elapsed += checkInterval;
    }
    throw TimeoutException(
      'Firma veritabani ${maxWait.inSeconds} saniyede acilamadi.',
    );
  }

  Future<Box<CompanyInfo>> _ensureBox() async {
    final existing = _companyBox;
    if (existing != null && existing.isOpen) return existing;
    _companyBox = Hive.isBoxOpen(_boxName)
        ? Hive.box<CompanyInfo>(_boxName)
        : await Hive.openBox<CompanyInfo>(_boxName);
    await _companySubscription?.cancel();
    _companySubscription =
        _companyBox!.watch().listen((_) => _refreshFromBox());
    return _companyBox!;
  }

  Future<void> saveCompanyInfo(CompanyInfo info) async {
    final box = await _ensureBox();
    if (box.isNotEmpty) {
      await box.putAt(0, info);
    } else {
      await box.add(info);
    }
    _refreshFromBox();
  }

  Future<void> updateLogo(
    Uint8List logoBytes, {
    double? width,
    double? height,
  }) async {
    final info = _companyInfo;
    if (info == null) return;
    info.logoBytes = logoBytes;
    if (width != null) info.logoWidth = width;
    if (height != null) info.logoHeight = height;
    await info.save();
    _refreshFromBox();
  }

  Future<void> deleteLogo() async {
    final info = _companyInfo;
    if (info == null) return;
    info.logoBytes = null;
    await info.save();
    _refreshFromBox();
  }

  void _refreshFromBox({bool notify = true}) {
    _companyInfo = _companyBox != null && _companyBox!.isNotEmpty
        ? _companyBox!.getAt(0)
        : null;
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    _companySubscription?.cancel();
    super.dispose();
  }
}
