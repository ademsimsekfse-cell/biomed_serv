import 'package:biomed_serv/providers/agent_provider.dart';
import 'package:biomed_serv/providers/company_provider.dart';
import 'package:biomed_serv/providers/customer_provider.dart';
import 'package:biomed_serv/providers/dashboard_provider.dart';
import 'package:biomed_serv/providers/device_personel_provider.dart';
import 'package:biomed_serv/providers/device_provider.dart';
import 'package:biomed_serv/providers/expense_provider.dart';
import 'package:biomed_serv/providers/expense_report_provider.dart';
import 'package:biomed_serv/providers/fault_ticket_provider.dart';
import 'package:biomed_serv/providers/maintenance_form_provider.dart';
import 'package:biomed_serv/providers/maintenance_template_provider.dart';
import 'package:biomed_serv/providers/maintenance_template_v2_provider.dart';
import 'package:biomed_serv/providers/notification_provider.dart';
import 'package:biomed_serv/providers/report_template_provider.dart';
import 'package:biomed_serv/providers/search_provider.dart';
import 'package:biomed_serv/providers/service_form_provider.dart';
import 'package:biomed_serv/providers/stock_provider.dart';
import 'package:biomed_serv/providers/tender_provider.dart';
import 'package:biomed_serv/providers/technician_provider.dart';
import 'package:biomed_serv/screens/company_setup_screen.dart';
import 'package:biomed_serv/screens/home_screen.dart';
import 'package:biomed_serv/models/technician.dart';
import 'package:biomed_serv/services/auto_backup_service.dart';
import 'package:biomed_serv/services/app_ui_settings_service.dart';
import 'package:biomed_serv/services/backup_service.dart';
import 'package:biomed_serv/services/connectivity_service.dart';
import 'package:biomed_serv/services/database_service.dart';
import 'package:biomed_serv/services/lan_auto_sync_service.dart';
import 'package:biomed_serv/services/notification_service.dart';
import 'package:biomed_serv/services/portable_runtime_service.dart';
import 'package:biomed_serv/services/sound_service.dart';
import 'package:biomed_serv/services/storage_location_service.dart';
import 'package:biomed_serv/services/technical_assignment_service.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

const bool _seedDemoData = false;

bool get _requiresManualStorageSetup {
  if (kIsWeb) return false;
  switch (defaultTargetPlatform) {
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
      return true;
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return false;
  }
}

bool get _isDesktopTarget {
  if (kIsWeb) return false;
  switch (defaultTargetPlatform) {
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
      return true;
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return false;
  }
}

void main() async {
  // TÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â¦ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œM BAÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂLATMAYI TRY-CATCH ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°LE SAR
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // HATA YAKALAMA
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint(
          'ÃƒÆ’Ã¢â‚¬ÂÃƒâ€¦Ã‚Â¸ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¨ FLUTTER ERROR: ${details.exception}');
    };
    ErrorWidget.builder = _buildRuntimeErrorWidget;

    // HIVE BAÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂLAT - Windows/desktop tarafÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â±nda portable klasÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¶rde tutulur.
    final hivePath = await PortableRuntimeService().hiveDirectoryPath();
    Hive.init(hivePath);
    await initializeDateFormatting('tr_TR', null);

    // DATABASE BAÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂLAT
    await DatabaseService.initDatabase();

    // BÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°LDÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°RÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°M SERVÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°SÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â° BAÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂLAT
    await LocalNotificationService.initialize();
    await LocalNotificationService.createNotificationChannel();

    // ÃƒÆ’Ã¢â‚¬ÂÃƒâ€¦Ã‚Â¸ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚ÂÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â  SES EFEKT SERVÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°SÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â° BAÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂLAT
    await SoundService().initialize();

    // UYGULAMAYI BAÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂLAT
    runApp(const MyApp());
  } catch (e, stack) {
    // HATA DURUMUNDA HATA EKRANI GÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œSTER
    debugPrint(
        'ÃƒÆ’Ã¢â‚¬ÂÃƒâ€¦Ã‚Â¸ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¨ BAÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂLATMA HATASI: $e');
    debugPrint(
        'ÃƒÆ’Ã¢â‚¬ÂÃƒâ€¦Ã‚Â¸ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã¢â‚¬Å“ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â Stack: $stack');
    runApp(ErrorApp(error: e.toString(), stack: stack.toString()));
  }
}

Widget _buildRuntimeErrorWidget(FlutterErrorDetails errorDetails) {
  return Scaffold(
    body: Container(
      padding: const EdgeInsets.all(16),
      color: Colors.red.shade50,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade700),
            const SizedBox(height: 16),
            Text(
              'Uygulama Hatasi',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              errorDetails.exception.toString(),
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Lutfen uygulamayi yeniden baslatin.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    ),
  );
}

ThemeData _buildAppTheme({Color seed = const Color(0xFF1565C0)}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.light,
  );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: 'OpenSans',
    scaffoldBackgroundColor: const Color(0xFFF6F8FB),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: scheme.primary,
      foregroundColor: Colors.white,
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 19,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blueGrey.shade50),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blueGrey.shade100),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(64, 48),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: scheme.primary.withValues(alpha: 0.35)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Temel Servisler
        Provider<DatabaseService>(create: (_) => DatabaseService()),
        ChangeNotifierProvider(
          create: (_) => StorageLocationService()..init(),
        ),
        ChangeNotifierProvider(
          create: (ctx) =>
              AutoBackupService(ctx.read<DatabaseService>())..init(),
        ),
        ChangeNotifierProvider(
          create: (ctx) => AppUiSettingsService()..init(),
        ),

        // Temel Veri SaÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¸layÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â±cÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â±larÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â±
        ChangeNotifierProxyProvider<DatabaseService, CustomerProvider>(
          create: (context) =>
              CustomerProvider(context.read<DatabaseService>()),
          update: (context, dbService, previous) => CustomerProvider(dbService),
        ),
        ChangeNotifierProxyProvider<DatabaseService, StockProvider>(
          create: (context) => StockProvider(context.read<DatabaseService>()),
          update: (context, dbService, previous) => StockProvider(dbService),
        ),
        ChangeNotifierProxyProvider<DatabaseService, DeviceProvider>(
          create: (context) => DeviceProvider(context.read<DatabaseService>()),
          update: (context, dbService, previous) => DeviceProvider(dbService),
        ),
        ChangeNotifierProxyProvider<DatabaseService, TenderProvider>(
          create: (context) => TenderProvider(context.read<DatabaseService>()),
          update: (context, dbService, previous) => TenderProvider(dbService),
        ),
        ChangeNotifierProxyProvider<DatabaseService, ServiceFormProvider>(
          create: (context) =>
              ServiceFormProvider(context.read<DatabaseService>()),
          update: (context, dbService, previous) =>
              ServiceFormProvider(dbService),
        ),
        ChangeNotifierProxyProvider<DatabaseService, MaintenanceFormProvider>(
          create: (context) =>
              MaintenanceFormProvider(context.read<DatabaseService>()),
          update: (context, dbService, previous) =>
              MaintenanceFormProvider(dbService),
        ),
        ChangeNotifierProxyProvider<DatabaseService,
            MaintenanceTemplateProvider>(
          create: (context) =>
              MaintenanceTemplateProvider(context.read<DatabaseService>()),
          update: (context, dbService, previous) =>
              MaintenanceTemplateProvider(dbService),
        ),
        ChangeNotifierProvider(
          create: (ctx) =>
              MaintenanceTemplateV2Provider(ctx.read<DatabaseService>()),
        ),
        // Rapor ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂablonlarÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â± Provider
        ChangeNotifierProvider(
          create: (ctx) => ReportTemplateProvider(ctx.read<DatabaseService>())
            ..addDefaultTemplates(),
        ),
        // Masraf Provider
        ChangeNotifierProvider(
          create: (ctx) {
            final provider = ExpenseProvider(ctx.read<DatabaseService>());
            if (kDebugMode && _seedDemoData) {
              // Demo veriler sadece gelistirme kurulumunda eklenir.
              // Gercek kullanicinin finans ve bildirim ekranlari temiz baslamali.
              provider.addDemoExpenses();
            }
            return provider;
          },
        ),
        // Masraf Raporu Provider
        ChangeNotifierProvider(
          create: (ctx) => ExpenseReportProvider(ctx.read<DatabaseService>()),
        ),
        // Arama Provider
        ChangeNotifierProvider(
          create: (ctx) => SearchProvider(ctx.read<DatabaseService>()),
        ),
        // Bildirim Provider
        ChangeNotifierProvider(
          create: (ctx) {
            final provider = NotificationProvider(ctx.read<DatabaseService>());
            if (kDebugMode && _seedDemoData) {
              provider.addDemoNotifications();
            }
            return provider;
          },
        ),
        // Sorumlu Personel Provider
        ChangeNotifierProvider(
          create: (ctx) {
            final provider =
                DevicePersonelProvider(ctx.read<DatabaseService>());
            if (kDebugMode && _seedDemoData) {
              provider.addDemoPersonels();
            }
            return provider;
          },
        ),
        // Teknisyen Provider
        ChangeNotifierProvider(
          create: (ctx) => TechnicianProvider()..init(),
        ),
        // Firma Bilgileri Provider
        ChangeNotifierProvider(
          create: (ctx) => CompanyProvider()..init(),
        ),
        // ArÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â±za KayÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â±tlarÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â± Provider
        ChangeNotifierProvider(
          create: (ctx) => FaultTicketProvider(ctx.read<DatabaseService>()),
        ),
        // BaÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¸lantÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â± Durumu Provider
        ChangeNotifierProvider(
          create: (ctx) => ConnectivityService(),
        ),
        ChangeNotifierProvider(
          lazy: false,
          create: (ctx) =>
              LanAutoSyncService(ctx.read<DatabaseService>())..init(),
        ),
        ChangeNotifierProvider(
          create: (ctx) => TechnicalAssignmentService(),
        ),

        // Analiz ve AkÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â±llÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â± SaÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¸layÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â±cÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â±lar (DiÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¸erlerine BaÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â±mlÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â±)
        ChangeNotifierProxyProvider4<
            ServiceFormProvider,
            MaintenanceFormProvider,
            DeviceProvider,
            ExpenseProvider,
            DashboardProvider>(
          create: (context) => DashboardProvider(
            context.read<ServiceFormProvider>(),
            context.read<MaintenanceFormProvider>(),
            context.read<DeviceProvider>(),
            context.read<ExpenseProvider>(),
          ),
          update: (context, serviceForms, maintenanceForms, devices, expenses,
                  previous) =>
              DashboardProvider(
                  serviceForms, maintenanceForms, devices, expenses),
        ),
        ChangeNotifierProxyProvider4<StockProvider, TenderProvider,
            DeviceProvider, ServiceFormProvider, AgentProvider>(
          create: (context) => AgentProvider(
            context.read<StockProvider>(),
            context.read<TenderProvider>(),
            context.read<DeviceProvider>(),
            context.read<ServiceFormProvider>(),
          ),
          update: (context, stock, tender, device, service, previous) =>
              AgentProvider(stock, tender, device, service),
        ),
      ],
      child: Consumer<AppUiSettingsService>(
        builder: (context, uiSettings, child) {
          return MaterialApp(
            title: 'Biomed Servis',
            debugShowCheckedModeBanner: false,
            theme: _buildAppTheme(seed: uiSettings.seedColor),
            builder: (context, child) => child ?? const SizedBox.shrink(),
            home: const InitialSetupWrapper(),
          );
        },
      ),
    );
  }
}

/// HATA DURUMUNDA GOSTERILEN UYGULAMA
class ErrorApp extends StatelessWidget {
  final String error;
  final String stack;

  const ErrorApp({super.key, required this.error, required this.stack});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.red.shade50,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Icon(Icons.error_outline, size: 80, color: Colors.red.shade700),
                const SizedBox(height: 24),
                Text(
                  'UYGULAMA BASLATMA HATASI',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    error,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red.shade800,
                      fontFamily: 'monospace',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Cozum:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSolutionItem('1. Uygulamayi tamamen kapatin'),
                      _buildSolutionItem(
                          '2. Ayarlar > Uygulamalar > Biomed Servis > Verileri Temizle'),
                      _buildSolutionItem(
                          '3. Veya uygulamayi kaldirip yeniden kurun'),
                      _buildSolutionItem('4. Sonra tekrar deneyin'),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  'Hata detaylari gelistirici icin kaydedildi',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSolutionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 18, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }
}

class InitialSetupWrapper extends StatefulWidget {
  const InitialSetupWrapper({super.key});

  @override
  State<InitialSetupWrapper> createState() => _InitialSetupWrapperState();
}

class _InitialSetupWrapperState extends State<InitialSetupWrapper>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _error;
  String _versionLabel = '1.1.0';
  late final AnimationController _startupAnimationController;

  @override
  void initState() {
    super.initState();
    _startupAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _loadVersionInfo();
    _checkInitialSetup();
  }

  Future<void> _loadVersionInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _versionLabel = info.buildNumber.isEmpty
            ? info.version
            : '${info.version}+${info.buildNumber}';
      });
    } catch (_) {
      // Widget tests and unsupported platforms use the release fallback.
    }
  }

  @override
  void dispose() {
    _startupAnimationController.dispose();
    super.dispose();
  }

  Future<void> _checkInitialSetup() async {
    final startedAt = DateTime.now();
    try {
      final technicianProvider =
          Provider.of<TechnicianProvider>(context, listen: false);
      final companyProvider =
          Provider.of<CompanyProvider>(context, listen: false);
      final storageService =
          Provider.of<StorageLocationService>(context, listen: false);

      // ÃƒÆ’Ã¢â‚¬ÂÃƒâ€¦Ã‚Â¸ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â´ KRÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°TÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°K: Provider'larÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â±n init() tamamlanmasÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â±nÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â± bekle
      debugPrint(
          'ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â³ Provider init bekleniyor...');
      await _waitForProviderInit(technicianProvider, companyProvider);
      await storageService.init();
      if (!_requiresManualStorageSetup && !storageService.storageConfigured) {
        await storageService.configure(
          workspaceDirectory: await storageService.defaultWorkspaceDirectory(),
          autoBackupEnabled: true,
        );
      }
      debugPrint(
          'ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã¢â‚¬Â¦ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¦ Provider init tamam');

      if (!mounted) return;
      final elapsed = DateTime.now().difference(startedAt);
      const minimumWelcomeDuration = Duration(milliseconds: 2200);
      if (elapsed < minimumWelcomeDuration) {
        await Future.delayed(minimumWelcomeDuration - elapsed);
      }
      if (!mounted) return;

      setState(() => _isLoading = false);

      if (!storageService.storageConfigured ||
          !technicianProvider.hasTechnician ||
          !companyProvider.hasCompanyInfo) {
        // Kurulum gerekli
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const SetupWizardScreen()),
          );
        });
      } else {
        // Kurulum tamam
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        });
      }
    } catch (e, stack) {
      debugPrint(
          'ÃƒÆ’Ã¢â‚¬ÂÃƒâ€¦Ã‚Â¸ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¨ Setup hatasÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â±: $e');
      debugPrint(
          'ÃƒÆ’Ã¢â‚¬ÂÃƒâ€¦Ã‚Â¸ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã¢â‚¬Å“ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â Stack: $stack');
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  /// Provider'larÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â±n init() tamamlanmasÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â±nÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â± bekle (max 5 saniye)
  Future<void> _waitForProviderInit(
    TechnicianProvider techProvider,
    CompanyProvider companyProvider,
  ) async {
    const maxWait = Duration(seconds: 5);
    const checkInterval = Duration(milliseconds: 100);
    var elapsed = Duration.zero;

    while (elapsed < maxWait) {
      // Box'lar aÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â±k mÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â± kontrol et
      final techReady = techProvider.technicianBox != null;
      final companyReady = companyProvider.companyBox != null;

      if (techReady && companyReady) {
        debugPrint(
            'ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã¢â‚¬Â¦ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¦ Her iki provider hazÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â±r');
        return;
      }

      debugPrint(
          'ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â³ Bekleniyor... techReady=$techReady, companyReady=$companyReady');
      await Future.delayed(checkInterval);
      elapsed += checkInterval;
    }

    throw TimeoutException(
        'Provider init 5 saniyeyi aÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¸tÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â±');
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: Container(
          padding: const EdgeInsets.all(24),
          color: Colors.red.shade50,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade700),
                const SizedBox(height: 16),
                Text(
                  'Başlatma Hatası',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _isLoading = true;
                    });
                    _checkInitialSetup();
                  },
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body:
          _isLoading ? _buildStartupLoading(context) : const SizedBox.shrink(),
    );
  }

  Widget _buildStartupLoading(BuildContext context) {
    final technician = context.watch<TechnicianProvider>().currentTechnician;
    final company = context.watch<CompanyProvider>().companyInfo;
    final firstName = technician?.fullName.trim().split(RegExp(r'\s+')).first;
    final greeting = firstName == null || firstName.isEmpty
        ? 'Hoş geldiniz'
        : 'Hoş geldiniz, $firstName';
    final companyName = company?.companyName.trim();
    final companyContacts = [
      if (company?.phone?.trim().isNotEmpty == true) company!.phone!.trim(),
      if (company?.email?.trim().isNotEmpty == true) company!.email!.trim(),
    ];

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFF4F7F9),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 56,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const Spacer(),
                      AnimatedBuilder(
                        animation: _startupAnimationController,
                        builder: (context, child) {
                          final pulse =
                              0.97 + (_startupAnimationController.value * 0.04);
                          return Transform.scale(
                            scale: pulse,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(26),
                              child: Image.asset(
                                'assets/branding/biomed_servis_logo.png',
                                width: 144,
                                height: 144,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const SizedBox(
                                    width: 144,
                                    height: 144,
                                    child: Icon(
                                      Icons.health_and_safety,
                                      size: 72,
                                      color: Color(0xFF1565C0),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 26),
                      Text(
                        greeting,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF102A43),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        companyName == null || companyName.isEmpty
                            ? 'Biomed Servis'
                            : companyName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                      if (companyContacts.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          companyContacts.join('  •  '),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: Colors.blueGrey.shade700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        company == null
                            ? 'İlk kurulum hazırlanıyor'
                            : 'Çalışma alanınız hazırlanıyor',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blueGrey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 26),
                      SizedBox(
                        width: 220,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 6,
                            backgroundColor: Colors.white,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 28),
                      Text(
                        'Biomed Servis  •  Sürüm $_versionLabel',
                        style: TextStyle(
                          color: Colors.blueGrey.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Fejox',
                        style: TextStyle(
                          color: Colors.blueGrey.shade500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class BackupSetupStep extends StatefulWidget {
  final Future<void> Function() onContinue;

  const BackupSetupStep({
    super.key,
    required this.onContinue,
  });

  @override
  State<BackupSetupStep> createState() => _BackupSetupStepState();
}

class _BackupSetupStepState extends State<BackupSetupStep> {
  bool _isLoading = true;
  bool _isRestoring = false;
  String? _error;
  List<BackupInfo> _backups = [];
  late final BackupService _backupService;

  @override
  void initState() {
    super.initState();
    _backupService = BackupService(context.read<DatabaseService>());
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final backups = await _backupService.getBackupHistory();
      if (!mounted) return;
      setState(() => _backups = backups);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreFromPicker() async {
    await _runRestore(() => _backupService.restoreFromPicker());
  }

  Future<void> _restoreBackup(BackupInfo backup) async {
    await _runRestore(() => _backupService.restoreFromBackup(backup.path));
  }

  Future<void> _runRestore(Future<void> Function() restore) async {
    setState(() => _isRestoring = true);
    try {
      await restore();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yedek geri yuklendi. Kurulum kontrol ediliyor...'),
          backgroundColor: Colors.green,
        ),
      );
      await widget.onContinue();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Yedek geri yuklenemedi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final latestBackup = _backups.isNotEmpty ? _backups.first : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeroCard(),
          const SizedBox(height: 20),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            _buildStatusCard(
              icon: Icons.info_outline,
              title: 'Yedek kontrolu yapilamadi',
              message: 'Temiz kuruluma devam edebilirsiniz.',
              color: Colors.orange,
            )
          else if (latestBackup == null)
            _buildStatusCard(
              icon: Icons.folder_off_outlined,
              title: 'Bu cihazda yedek bulunamadi',
              message:
                  'Devam edince once calisma ve yedek klasorunu, sonra teknisyen ve sirket bilgilerini alacagiz.',
              color: Colors.blueGrey,
            )
          else
            _buildBackupFoundCard(latestBackup),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _isRestoring ? null : _restoreFromPicker,
            icon: const Icon(Icons.upload_file),
            label: const Text('Yedek Dosyasi Sec (Drive / ZIP)'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _isRestoring ? null : widget.onContinue,
            icon: _isRestoring
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward),
            label: Text(_isRestoring
                ? 'Geri yukleniyor...'
                : 'Temiz Kuruluma Devam Et'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.health_and_safety, color: Colors.white, size: 36),
          SizedBox(height: 16),
          Text(
            'Biomed Servis kuruluma hazir',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Once yedeginiz var mi kontrol ediyoruz. Veri varsa geri yukleyebilir, yoksa hizlica temiz kurulum yapabilirsiniz.',
            style: TextStyle(color: Colors.white70, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(message, style: TextStyle(color: Colors.grey.shade700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupFoundCard(BackupInfo backup) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green.shade50,
                  child: const Icon(Icons.backup, color: Colors.green),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Bu cihazda yedek bulundu',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(backup.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${backup.formattedDate} - ${backup.formattedSize}',
                style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _isRestoring ? null : () => _restoreBackup(backup),
              icon: const Icon(Icons.restore),
              label: const Text('Bu Yedekten Geri Yukle'),
            ),
          ],
        ),
      ),
    );
  }
}

class StorageSetupStep extends StatefulWidget {
  final Future<void> Function() onContinue;

  const StorageSetupStep({
    super.key,
    required this.onContinue,
  });

  @override
  State<StorageSetupStep> createState() => _StorageSetupStepState();
}

class _StorageSetupStepState extends State<StorageSetupStep> {
  final _workspaceController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _autoBackupEnabled = true;
  String? _workspacePath;
  String? _error;

  String get _backupPreviewPath {
    final base = _workspaceController.text.trim().isNotEmpty
        ? _workspaceController.text.trim()
        : (_workspacePath ?? '');
    if (base.isEmpty) return '-';
    return '$base${Platform.pathSeparator}Backups';
  }

  @override
  void dispose() {
    _workspaceController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final storage = context.read<StorageLocationService>();
    try {
      await storage.init();
      final defaultPath = await storage.defaultWorkspaceDirectory();
      if (!mounted) return;
      setState(() {
        _workspacePath = storage.workspaceDirectory ?? defaultPath;
        _workspaceController.text = _workspacePath ?? '';
        _autoBackupEnabled = storage.autoBackupEnabled;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDirectory() async {
    final storage = context.read<StorageLocationService>();
    try {
      final path = await storage.pickWorkspaceDirectory();
      if (!mounted) return;
      if (path == null || path.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Klasor secimi iptal edildi. Isterseniz yolu elle yazabilirsiniz.',
            ),
          ),
        );
        return;
      }
      setState(() {
        _workspacePath = path.trim();
        _workspaceController.text = _workspacePath!;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Klasor secici acilamadi. Yolu elle yazabilirsiniz: $e'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _useDefaultDirectory() async {
    final defaultPath = await context
        .read<StorageLocationService>()
        .defaultWorkspaceDirectory();
    if (!mounted) return;
    setState(() {
      _workspacePath = defaultPath;
      _workspaceController.text = defaultPath;
    });
  }

  Future<void> _saveAndContinue() async {
    final path = _workspaceController.text.trim().isNotEmpty
        ? _workspaceController.text.trim()
        : _workspacePath?.trim();
    if (path == null || path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lutfen calisma klasoru secin'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final storage = context.read<StorageLocationService>();
      final autoBackup = context.read<AutoBackupService>();
      await storage.configure(
        workspaceDirectory: path,
        autoBackupEnabled: _autoBackupEnabled,
      );
      await autoBackup.setEnabled(_autoBackupEnabled);
      await widget.onContinue();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Depolama ayari kaydedilemedi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              if (_error != null)
                Card(
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Varsayilan klasor okunamadi: $_error',
                      style: TextStyle(color: Colors.orange.shade900),
                    ),
                  ),
                ),
              _buildPathCard(),
              const SizedBox(height: 16),
              _buildAutoBackupCard(),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _isSaving ? null : _saveAndContinue,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle),
                label:
                    Text(_isSaving ? 'Hazirlaniyor...' : 'Kaydet ve Devam Et'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.inventory_2_outlined, color: Colors.white, size: 34),
          SizedBox(height: 14),
          Text(
            'Merkez veri kasasi',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Desktop merkez bu klasoru calisma alani olarak kullanir. Isterseniz kendi klasorunuzu secebilir, yedekleri ise ayni alanin icindeki Backups klasorunde duzenli olarak tutabilirsiniz.',
            style: TextStyle(color: Colors.white70, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildPathCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  child: Icon(Icons.folder_open, color: Colors.blue.shade700),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Calisma klasoru ve yedekler',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickDirectory,
                  icon: const Icon(Icons.drive_folder_upload),
                  label: const Text('Sec'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _workspaceController,
              onChanged: (value) => setState(() => _workspacePath = value),
              decoration: InputDecoration(
                labelText: 'Kurulum / calisma yolu',
                hintText: 'Orn: C:\\BiomedServis veya D:\\ServisVerileri',
                prefixIcon: const Icon(Icons.folder),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueGrey.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bu adimda ne olacak?',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '1. Sistem bu klasoru calisma alani olarak kullanir.',
                    style: TextStyle(color: Colors.blueGrey.shade800),
                  ),
                  Text(
                    '2. Yedekler otomatik olarak su klasore yazilir:',
                    style: TextStyle(color: Colors.blueGrey.shade800),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    _backupPreviewPath,
                    style: TextStyle(
                      color: Colors.blueGrey.shade900,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _useDefaultDirectory,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Sistemin onerdigi guvenli yolu kullan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoBackupCard() {
    return Card(
      child: SwitchListTile(
        value: _autoBackupEnabled,
        onChanged: (value) => setState(() => _autoBackupEnabled = value),
        secondary: CircleAvatar(
          backgroundColor: Colors.green.shade50,
          child: Icon(Icons.cloud_done_outlined, color: Colors.green.shade700),
        ),
        title: const Text(
          'Otomatik yedekleme aktif',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text(
          'Sistem belirli araliklarla Excel ve CSV iceren ZIP yedegi uretir.',
        ),
      ),
    );
  }
}

class FirstSetupTechnicianStep extends StatefulWidget {
  final VoidCallback onSaved;

  const FirstSetupTechnicianStep({
    super.key,
    required this.onSaved,
  });

  @override
  State<FirstSetupTechnicianStep> createState() =>
      _FirstSetupTechnicianStepState();
}

class _FirstSetupTechnicianStepState extends State<FirstSetupTechnicianStep> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _titleController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  Uint8List? _photoBytes;
  bool _isSaving = false;
  bool get _isDesktop => _isDesktopTarget;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _titleController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final provider = context.read<TechnicianProvider>();
      await provider.init();

      final technician = Technician(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        title: _emptyToNull(_titleController.text),
        phone: _emptyToNull(_phoneController.text),
        email: _emptyToNull(_emailController.text),
        photoBytes: _photoBytes,
        address: _emptyToNull(_addressController.text),
      );

      if (provider.technicians.isNotEmpty) {
        await provider.updateTechnician(0, technician);
      } else {
        await provider.addTechnician(technician);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isDesktop
                ? 'Merkez kullanicisi kaydedildi'
                : 'Teknisyen bilgileri kaydedildi',
          ),
          backgroundColor: Colors.green,
        ),
      );
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Teknisyen kaydedilemedi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        imageQuality: 78,
        maxWidth: 900,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() => _photoBytes = bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fotograf secilemedi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.grey.shade50,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 18),
                      _buildPhotoPicker(),
                      const SizedBox(height: 18),
                      _buildField(
                        controller: _firstNameController,
                        label: 'Ad',
                        icon: Icons.person,
                        validatorMessage: 'Ad zorunludur',
                      ),
                      const SizedBox(height: 12),
                      _buildField(
                        controller: _lastNameController,
                        label: 'Soyad',
                        icon: Icons.person_outline,
                        validatorMessage: 'Soyad zorunludur',
                      ),
                      const SizedBox(height: 12),
                      _buildField(
                        controller: _titleController,
                        label: _isDesktop ? 'Unvan *' : 'Unvan',
                        icon: Icons.badge,
                        hint: 'Biyomedikal Teknikeri, Servis Uzmani...',
                        validatorMessage:
                            _isDesktop ? 'Unvan zorunludur' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildField(
                        controller: _phoneController,
                        label: _isDesktop ? 'Telefon *' : 'Telefon',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                        hint: '0 (5XX) XXX XX XX',
                        validatorMessage:
                            _isDesktop ? 'Telefon zorunludur' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildField(
                        controller: _emailController,
                        label: 'E-posta',
                        icon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                        hint: 'ornek@email.com',
                      ),
                      const SizedBox(height: 12),
                      _buildField(
                        controller: _addressController,
                        label: _isDesktop ? 'Adres *' : 'Adres',
                        icon: Icons.location_on_outlined,
                        hint: 'Merkez kullanıcısının adres bilgisi',
                        maxLines: 2,
                        validatorMessage:
                            _isDesktop ? 'Adres zorunludur' : null,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _isSaving ? null : _save,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save),
                        label: Text(_isSaving ? 'Kaydediliyor...' : 'Kaydet'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    final title = _isDesktop ? 'Merkez Kullanıcısı' : 'Teknisyen Bilgileri';
    final subtitle = _isDesktop
        ? 'Desktop merkezde işlem yapan ana kullanıcı, rapor ve senkron kayıtlarında bu kimlikle görünür.'
        : 'Formlar, raporlar ve cihaz hareketleri bu teknisyen kimligiyle eslenecek.';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFB9D8FF)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.engineering,
              color: Color(0xFF1565C0),
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12.5, height: 1.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPicker() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.blueGrey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: const Color(0xFFEAF3FF),
              backgroundImage:
                  _photoBytes == null ? null : MemoryImage(_photoBytes!),
              child: _photoBytes == null
                  ? const Icon(Icons.person_add_alt_1,
                      color: Color(0xFF1565C0), size: 30)
                  : null,
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Teknisyen fotografi',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Karsilama kartinda ve teknisyen profilinde gorunur.',
                    style: TextStyle(fontSize: 12.5, height: 1.25),
                  ),
                ],
              ),
            ),
            PopupMenuButton<ImageSource>(
              tooltip: 'Fotograf ekle',
              onSelected: _pickPhoto,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: ImageSource.camera,
                  child: ListTile(
                    leading: Icon(Icons.photo_camera),
                    title: Text('Kamera'),
                  ),
                ),
                PopupMenuItem(
                  value: ImageSource.gallery,
                  child: ListTile(
                    leading: Icon(Icons.photo_library),
                    title: Text('Galeri'),
                  ),
                ),
              ],
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_a_photo,
                        size: 18, color: Color(0xFF1565C0)),
                    const SizedBox(width: 6),
                    Text(
                      _photoBytes == null ? 'Ekle' : 'Degistir',
                      style: const TextStyle(
                        color: Color(0xFF1565C0),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    String? validatorMessage,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validatorMessage == null
          ? null
          : (value) =>
              value == null || value.trim().isEmpty ? validatorMessage : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
    );
  }
}

class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupStepMeta {
  final int index;
  final String label;
  final IconData icon;

  const _SetupStepMeta(this.index, this.label, this.icon);
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  int _currentStep = 0;
  late final PageController _pageController;
  bool _isNavigating = false;

  bool get _hasStorageStep => _requiresManualStorageSetup;
  bool get _isDesktop => _isDesktopTarget;
  int get _stepCount => _hasStorageStep ? 4 : 3;
  int get _technicianStep => _hasStorageStep ? 2 : 1;
  int get _companyStep => _hasStorageStep ? 3 : 2;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    debugPrint(
        'ÃƒÆ’Ã¢â‚¬ÂÃƒâ€¦Ã‚Â¸ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â SetupWizardScreen init');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// ÃƒÆ’Ã¢â‚¬ÂÃƒâ€¦Ã‚Â¸ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â GÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¼venli step geÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§iÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¸i
  void _goToStep(int step) {
    if (_isNavigating || !mounted) return;
    if (step < 0 || step >= _stepCount) return;

    setState(() {
      _isNavigating = true;
      _currentStep = step;
    });

    _pageController
        .animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    )
        .then((_) {
      if (mounted) {
        setState(() => _isNavigating = false);
      }
    });
  }

  Future<void> _continueAfterBackupCheck() async {
    final technicianProvider = context.read<TechnicianProvider>();
    final companyProvider = context.read<CompanyProvider>();
    final storageService = context.read<StorageLocationService>();
    final autoBackupService = context.read<AutoBackupService>();

    await technicianProvider.init();
    await companyProvider.init();
    await storageService.init();
    if (!mounted) return;

    if (!storageService.storageConfigured && _hasStorageStep) {
      _goToStep(1);
      return;
    }

    if (!storageService.storageConfigured) {
      await storageService.configure(
        workspaceDirectory: await storageService.defaultWorkspaceDirectory(),
        autoBackupEnabled: true,
      );
      await autoBackupService.setEnabled(true);
      if (!mounted) return;
    }

    if (technicianProvider.hasTechnician && companyProvider.hasCompanyInfo) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
      return;
    }

    _goToStep(
        technicianProvider.hasTechnician ? _companyStep : _technicianStep);
  }

  Future<void> _continueAfterStorageSetup() async {
    final technicianProvider = context.read<TechnicianProvider>();
    final companyProvider = context.read<CompanyProvider>();

    await technicianProvider.init();
    await companyProvider.init();
    if (!mounted) return;

    if (technicianProvider.hasTechnician && companyProvider.hasCompanyInfo) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
      return;
    }

    _goToStep(
        technicianProvider.hasTechnician ? _companyStep : _technicianStep);
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        'ÃƒÆ’Ã¢â‚¬ÂÃƒâ€¦Ã‚Â¸ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â SetupWizardScreen build: currentStep=$_currentStep');

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: _buildStepProgress(),
            ),

            const Divider(),

            // Step Content - PageView ile
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Manuel kontrol
                children: [
                  BackupSetupStep(onContinue: _continueAfterBackupCheck),
                  if (_hasStorageStep)
                    StorageSetupStep(onContinue: _continueAfterStorageSetup),
                  _buildTechnicianStep(),
                  _buildCompanyStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, IconData icon) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;

    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isActive ? Colors.blue : Colors.grey.shade300,
            shape: BoxShape.circle,
            border: isCurrent ? Border.all(color: Colors.blue, width: 3) : null,
          ),
          child: Icon(
            isActive && _currentStep > step ? Icons.check : icon,
            color: isActive ? Colors.white : Colors.grey.shade600,
            size: 20,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isActive ? Colors.blue : Colors.grey.shade600,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepProgress() {
    final steps = [
      _SetupStepMeta(0, 'Yedek', Icons.restore),
      if (_hasStorageStep) _SetupStepMeta(1, 'Klasör', Icons.folder_copy),
      _SetupStepMeta(
        _technicianStep,
        _isDesktop ? 'Kullanıcı' : 'Teknisyen',
        Icons.person,
      ),
      _SetupStepMeta(_companyStep, 'Firma', Icons.business),
    ];

    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          _buildStepIndicator(steps[i].index, steps[i].label, steps[i].icon),
          if (i != steps.length - 1)
            Expanded(child: _buildStepLine(steps[i + 1].index)),
        ],
      ],
    );
  }

  Widget _buildStepLine(int targetStep) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 2,
      color: _currentStep >= targetStep ? Colors.blue : Colors.grey.shade300,
    );
  }

  Widget _buildTechnicianStep() {
    return Column(
      children: [
        Expanded(
          child: FirstSetupTechnicianStep(
            onSaved: () {
              debugPrint(
                  'ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã¢â‚¬Â¦ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¦ Teknisyen kaydedildi, next step...');
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _goToStep(_companyStep);
              });
            },
          ),
        ),
        // Navigation Button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _isNavigating
                    ? null
                    : () {
                        final hasTechnician =
                            context.read<TechnicianProvider>().hasTechnician;
                        if (hasTechnician) {
                          _goToStep(_companyStep);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _isDesktop
                                    ? 'Lutfen once merkez kullanicisini kaydedin'
                                    : 'Lutfen once teknisyen kaydedin',
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      },
                icon: _isNavigating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.arrow_forward),
                label: Text(_isNavigating ? 'Yukleniyor...' : 'Devam Et'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompanyStep() {
    return Column(
      children: [
        Expanded(
          child: CompanySetupScreen(
            isFirstSetup: true,
            onSaveSuccess: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            ),
          ),
        ),
        // Navigation Buttons
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              TextButton.icon(
                onPressed:
                    _isNavigating ? null : () => _goToStep(_technicianStep),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Geri'),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  final hasCompany =
                      context.read<CompanyProvider>().hasCompanyInfo;
                  if (hasCompany) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Lutfen firma bilgilerini kaydedin'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.check),
                label: const Text('Tamamla'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
