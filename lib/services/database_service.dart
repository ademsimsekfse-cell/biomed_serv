import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/company_info.dart';
import '../models/customer.dart';
import '../models/device.dart';
import '../models/device_module.dart';
import '../models/device_personel.dart';
import '../models/expense.dart';
import '../models/expense_report.dart';
import '../models/fault_ticket.dart';
import '../models/maintenance_form.dart';
import '../models/maintenance_template.dart';
import '../models/maintenance_template_v2.dart';
import '../models/notification.dart';
import '../models/report_template.dart';
import '../models/service_form.dart';
import '../models/stock.dart';
import '../models/technician.dart';
import '../models/tender.dart';

class DatabaseService {
  // 🔒 SINGLETON PATTERN
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  // 🔄 ATOMIC INIT FLAGS
  static bool _initialized = false;

  /// Veritabanını başlat (atomic - sadece bir kez çalışır)
  static Future<void> initDatabase() async {
    // 🔒 Thread-safe singleton init
    if (_initialized) {
      debugPrint('⚠️ DatabaseService zaten başlatılmış, atlanıyor');
      return;
    }

    debugPrint('🏁 DatabaseService.initDatabase() BAŞLADI');

    // NOT: Hive.initFlutter() main.dart'ta çağrıldı, burada tekrar çağırmayın!

    // Adaptörleri kaydet (zaten kayıtlıysa hatayı yut)
    try {
      Hive.registerAdapter(CompanyInfoAdapter());
      debugPrint('✅ CompanyInfoAdapter kaydedildi');
    } catch (e) {
      if (e.toString().contains('already')) {
        debugPrint('⚠️ CompanyInfoAdapter zaten kayıtlı, devam ediliyor');
      } else {
        rethrow;
      }
    }

    try {
      Hive.registerAdapter(TechnicianAdapter());
      debugPrint('✅ TechnicianAdapter kaydedildi');
    } catch (e) {
      if (e.toString().contains('already')) {
        debugPrint('⚠️ TechnicianAdapter zaten kayıtlı, devam ediliyor');
      } else {
        rethrow;
      }
    }
    // 🎯 ENUM Adaptörleri ÖNCE kaydedilmeli (Device'tan önce)
    _safeRegisterAdapter(OwnershipStatusAdapter(), 'OwnershipStatusAdapter');
    _safeRegisterAdapter(DeviceModuleTypeAdapter(), 'DeviceModuleTypeAdapter');
    _safeRegisterAdapter(CustomerAdapter(), 'CustomerAdapter');
    _safeRegisterAdapter(DeviceAdapter(), 'DeviceAdapter');
    _safeRegisterAdapter(TenderAdapter(), 'TenderAdapter');
    _safeRegisterAdapter(StockAdapter(), 'StockAdapter');
    _safeRegisterAdapter(ServiceFormAdapter(), 'ServiceFormAdapter');
    _safeRegisterAdapter(MaintenanceFormAdapter(), 'MaintenanceFormAdapter');
    _safeRegisterAdapter(
        MaintenanceTemplateAdapter(), 'MaintenanceTemplateAdapter');
    _safeRegisterAdapter(
        MaintenanceTemplateLineAdapter(), 'MaintenanceTemplateLineAdapter');
    _safeRegisterAdapter(
        MaintenancePeriodTypeAdapter(), 'MaintenancePeriodTypeAdapter');
    _safeRegisterAdapter(
        MaintenanceTemplateV2Adapter(), 'MaintenanceTemplateV2Adapter');
    _safeRegisterAdapter(
        ReportSectionTypeAdapter(), 'ReportSectionTypeAdapter');
    _safeRegisterAdapter(ReportSectionAdapter(), 'ReportSectionAdapter');
    _safeRegisterAdapter(ReportStyleAdapter(), 'ReportStyleAdapter');
    _safeRegisterAdapter(ReportLayoutTypeAdapter(), 'ReportLayoutTypeAdapter');
    _safeRegisterAdapter(LogoPositionAdapter(), 'LogoPositionAdapter');
    _safeRegisterAdapter(ReportTemplateAdapter(), 'ReportTemplateAdapter');
    _safeRegisterAdapter(ExpenseStatusAdapter(), 'ExpenseStatusAdapter');
    _safeRegisterAdapter(CollectionTypeAdapter(), 'CollectionTypeAdapter');
    _safeRegisterAdapter(ExpenseAdapter(), 'ExpenseAdapter');
    _safeRegisterAdapter(ExpenseReportAdapter(), 'ExpenseReportAdapter');
    _safeRegisterAdapter(NotificationTypeAdapter(), 'NotificationTypeAdapter');
    _safeRegisterAdapter(
        NotificationPriorityAdapter(), 'NotificationPriorityAdapter');
    _safeRegisterAdapter(AppNotificationAdapter(), 'AppNotificationAdapter');
    _safeRegisterAdapter(ReminderAdapter(), 'ReminderAdapter');
    _safeRegisterAdapter(DevicePersonelAdapter(), 'DevicePersonelAdapter');
    _safeRegisterAdapter(DeviceModuleAdapter(), 'DeviceModuleAdapter');

    // Arıza Kaydı Adaptörleri
    _safeRegisterAdapter(FaultTicketAdapter(), 'FaultTicketAdapter');
    _safeRegisterAdapter(TicketStatusAdapter(), 'TicketStatusAdapter');
    _safeRegisterAdapter(TicketTypeAdapter(), 'TicketTypeAdapter');

    // Kutuları (Box) aç - ATOMIC (hepsi ya açılır ya hiçbiri)
    final boxesToOpen = <Future<Box<dynamic>>>[
      _safeOpenBox<CompanyInfo>('company_info'),
      _safeOpenBox<Technician>('technicians'),
      _safeOpenBox<Customer>('customers'),
      _safeOpenBox<Device>('devices'),
      _safeOpenBox<Tender>('tenders'),
      _safeOpenBox<Stock>('stocks'),
      _safeOpenBox<Stock>('service_form_parts'),
      _safeOpenBox<ServiceForm>('service_forms'),
      _safeOpenBox<MaintenanceForm>('maintenance_forms'),
      _safeOpenBox<MaintenanceTemplate>('maintenance_templates'),
      _safeOpenBox<MaintenanceTemplateV2>('maintenance_templates_v2'),
      _safeOpenBox<ReportTemplate>('report_templates'),
      _safeOpenBox<Expense>('expenses'),
      _safeOpenBox<ExpenseReport>('expense_reports'),
      _safeOpenBox<AppNotification>('notifications'),
      _safeOpenBox<Reminder>('reminders'),
      _safeOpenBox<DevicePersonel>('device_personels'),
      _safeOpenBox<DeviceModule>('device_modules'),
      _safeOpenBox<FaultTicket>('fault_tickets'),
    ];

    try {
      await Future.wait(boxesToOpen);
      _initialized = true;
      debugPrint('✅ Tüm box\'lar açıldı');
    } catch (e) {
      debugPrint('🚨 Box açma HATASI: $e');
      rethrow;
    }

    debugPrint('✅ DatabaseService.initDatabase() TAMAMLANDI');
  }

  /// Güvenli box açma - zaten açıksa mevcut box'ı döndür
  static Future<Box<T>> _safeOpenBox<T>(String name) async {
    if (Hive.isBoxOpen(name)) {
      debugPrint('📦 $name zaten açık');
      return Hive.box<T>(name);
    }
    debugPrint('📦 $name açılıyor...');
    final box = await Hive.openBox<T>(name);
    debugPrint('✅ $name açıldı');
    return box;
  }

  /// Güvenli adapter kaydetme - zaten kayıtlıysa hatayı yut
  static void _safeRegisterAdapter<T>(TypeAdapter<T> adapter, String name) {
    try {
      Hive.registerAdapter(adapter);
      debugPrint('✅ $name kaydedildi');
    } catch (e) {
      if (e.toString().contains('already')) {
        debugPrint('⚠️ $name zaten kayıtlı, devam ediliyor');
      } else {
        rethrow;
      }
    }
  }

  // Firma Bilgileri kutusuna erişim
  Box<CompanyInfo> get companyInfoBox => Hive.box<CompanyInfo>('company_info');

  // Teknisyen kutusuna erişim
  Box<Technician> get techniciansBox => Hive.box<Technician>('technicians');

  // Müşteri kutusuna erişim
  Box<Customer> get customersBox => Hive.box<Customer>('customers');

  // Stok kutusuna erişim
  Box<Stock> get stocksBox => Hive.box<Stock>('stocks');

  Box<Stock> get serviceFormPartsBox => Hive.box<Stock>('service_form_parts');

  // Cihaz kutusuna erişim
  Box<Device> get devicesBox => Hive.box<Device>('devices');

  // İhale kutusuna erişim
  Box<Tender> get tendersBox => Hive.box<Tender>('tenders');

  // Servis Formu kutusuna erişim
  Box<ServiceForm> get serviceFormsBox =>
      Hive.box<ServiceForm>('service_forms');

  // Bakım Formu kutusuna erişim
  Box<MaintenanceForm> get maintenanceFormsBox =>
      Hive.box<MaintenanceForm>('maintenance_forms');

  // Bakım Şablonu kutusuna erişim
  Box<MaintenanceTemplate> get maintenanceTemplatesBox =>
      Hive.box<MaintenanceTemplate>('maintenance_templates');

  // Yeni Bakım Şablonu V2 kutusuna erişim
  Box<MaintenanceTemplateV2> get maintenanceTemplatesV2Box =>
      Hive.box<MaintenanceTemplateV2>('maintenance_templates_v2');

  // Rapor Şablonu kutusuna erişim
  Box<ReportTemplate> get reportTemplatesBox =>
      Hive.box<ReportTemplate>('report_templates');

  // Masraf kutusuna erişim
  Box<Expense> get expensesBox => Hive.box<Expense>('expenses');

  // Masraf Raporu kutusuna erişim
  Box<ExpenseReport> get expenseReportsBox =>
      Hive.box<ExpenseReport>('expense_reports');

  // Bildirim kutusuna erişim
  Box<AppNotification> get notificationsBox =>
      Hive.box<AppNotification>('notifications');

  // Hatırlatıcı kutusuna erişim
  Box<Reminder> get remindersBox => Hive.box<Reminder>('reminders');

  // Cihaz Personel kutusuna erişim
  Box<DevicePersonel> get devicePersonelsBox =>
      Hive.box<DevicePersonel>('device_personels');

  // Cihaz Modül kutusuna erişim
  Box<DeviceModule> get deviceModulesBox =>
      Hive.box<DeviceModule>('device_modules');

  // Arıza Kayıtları kutusuna erişim
  Box<FaultTicket> get faultTicketsBox =>
      Hive.box<FaultTicket>('fault_tickets');
}
