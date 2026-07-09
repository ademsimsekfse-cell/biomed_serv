import 'package:hive/hive.dart';

part 'report_template.g.dart';

/// Rapor bölüm tipi enum
@HiveType(typeId: 27)
enum ReportSectionType {
  @HiveField(0)
  companyHeader, // Şirket adı ve logo
  @HiveField(1)
  formNumber, // Form numarası
  @HiveField(2)
  customerDetail, // Kurum bilgileri
  @HiveField(3)
  deviceInfo, // Cihaz bilgileri
  @HiveField(4)
  serviceTimes, // Servis zamanları
  @HiveField(5)
  problemDetails, // Problem detayları
  @HiveField(6)
  actionsTaken, // Yapılan işlemler
  @HiveField(7)
  finalStatus, // Final durum
  @HiveField(8)
  spareParts, // Kullanılan parçalar
  @HiveField(9)
  signatures, // İmza alanları
  @HiveField(10)
  maintenancePeriod, // Bakım periyodu (bakım formu için)
  @HiveField(11)
  notes, // Notlar/Öneriler
  @HiveField(12)
  technicianInfo, // Teknisyen bilgileri
}

/// Rapor şablonu modeli
/// Kullanıcının gönderdiği tasarıma göre özelleştirilebilir raporlar
@HiveType(typeId: 28)
class ReportTemplate extends HiveObject {
  @HiveField(0)
  late String name; // Şablon adı (örn: "Standart Servis Raporu")

  @HiveField(1)
  String? description; // Açıklama

  @HiveField(2)
  List<ReportSection> sections; // Görünecek bölümler

  @HiveField(3)
  bool isDefault; // Varsayılan şablon mu?

  @HiveField(4)
  ReportStyle style; // Renk ve stil ayarları

  @HiveField(8)
  ReportLayoutType layoutType; // Rapor görünüm şekli

  @HiveField(5)
  bool isActive; // Aktif mi?

  @HiveField(6)
  late DateTime createdAt;

  @HiveField(7)
  late DateTime updatedAt;

  ReportTemplate({
    required this.name,
    this.description,
    List<ReportSection>? sections,
    this.isDefault = false,
    ReportStyle? style,
    this.isActive = true,
    this.layoutType = ReportLayoutType.classic,
  })  : sections = sections ?? [],
        style = style ?? ReportStyle(),
        createdAt = DateTime.now(),
        updatedAt = DateTime.now();

  /// Varsayılan servis raporu şablonu
  factory ReportTemplate.defaultServiceTemplate() {
    return ReportTemplate(
      name: 'Standart Servis Raporu',
      description: 'Gönderilen tasarıma göre standart servis raporu',
      isDefault: true,
      sections: [
        ReportSection(
            type: ReportSectionType.companyHeader, isVisible: true, order: 0),
        ReportSection(
            type: ReportSectionType.formNumber, isVisible: true, order: 1),
        ReportSection(
            type: ReportSectionType.customerDetail,
            isVisible: true,
            order: 2,
            title: 'Customer Detail'),
        ReportSection(
            type: ReportSectionType.deviceInfo,
            isVisible: true,
            order: 3,
            title: 'Device Info'),
        ReportSection(
            type: ReportSectionType.serviceTimes,
            isVisible: true,
            order: 4,
            title: 'Service Times'),
        ReportSection(
            type: ReportSectionType.problemDetails,
            isVisible: true,
            order: 5,
            title: 'Problem Details'),
        ReportSection(
            type: ReportSectionType.actionsTaken,
            isVisible: true,
            order: 6,
            title: 'Actions and Recommendations'),
        ReportSection(
            type: ReportSectionType.finalStatus,
            isVisible: true,
            order: 7,
            title: 'Final Status'),
        ReportSection(
            type: ReportSectionType.spareParts,
            isVisible: true,
            order: 8,
            title: 'Spare Parts'),
        ReportSection(
            type: ReportSectionType.signatures,
            isVisible: true,
            order: 9,
            title: 'Serviced By / Customer Approval'),
      ],
      style: ReportStyle(
        primaryColor: 0xFF2C3E50, // Koyu mavi-gri
        secondaryColor: 0xFFECF0F1, // Açık gri
        accentColor: 0xFF3498DB, // Mavi
        fontFamily: 'OpenSans',
        companyName: 'COMPANY NAME',
        showLogo: true,
      ),
    );
  }

  /// Varsayılan bakım raporu şablonu
  factory ReportTemplate.defaultMaintenanceTemplate() {
    return ReportTemplate(
      name: 'Standart Bakım Raporu',
      description: 'Periyodik bakım raporu şablonu',
      isDefault: true,
      sections: [
        ReportSection(
            type: ReportSectionType.companyHeader, isVisible: true, order: 0),
        ReportSection(
            type: ReportSectionType.formNumber, isVisible: true, order: 1),
        ReportSection(
            type: ReportSectionType.customerDetail, isVisible: true, order: 2),
        ReportSection(
            type: ReportSectionType.deviceInfo, isVisible: true, order: 3),
        ReportSection(
            type: ReportSectionType.maintenancePeriod,
            isVisible: true,
            order: 4),
        ReportSection(
            type: ReportSectionType.actionsTaken, isVisible: true, order: 5),
        ReportSection(
            type: ReportSectionType.spareParts, isVisible: true, order: 6),
        ReportSection(type: ReportSectionType.notes, isVisible: true, order: 7),
        ReportSection(
            type: ReportSectionType.signatures, isVisible: true, order: 8),
      ],
      style: ReportStyle(
        primaryColor: 0xFF27AE60, // Yeşil
        secondaryColor: 0xFFE8F8F5,
        accentColor: 0xFF2ECC71,
        fontFamily: 'OpenSans',
        companyName: 'COMPANY NAME',
        showLogo: true,
      ),
    );
  }

  /// Görünür bölümleri sıralı olarak döndür
  List<ReportSection> get visibleSections {
    final visible = sections.where((s) => s.isVisible).toList();
    visible.sort((a, b) => a.order.compareTo(b.order));
    return visible;
  }

  /// Belirli bir bölüm tipi görünür mü?
  bool isSectionVisible(ReportSectionType type) {
    return sections.any((s) => s.type == type && s.isVisible);
  }

  /// Belirli bir bölümün başlığı
  String getSectionTitle(ReportSectionType type) {
    final section = sections.firstWhere(
      (s) => s.type == type,
      orElse: () => ReportSection(type: type, isVisible: true, order: 0),
    );
    return section.title ?? _getDefaultTitle(type);
  }

  static String _getDefaultTitle(ReportSectionType type) {
    switch (type) {
      case ReportSectionType.companyHeader:
        return 'Şirket Bilgileri';
      case ReportSectionType.formNumber:
        return 'Form Numarası';
      case ReportSectionType.customerDetail:
        return 'Müşteri Detayı';
      case ReportSectionType.deviceInfo:
        return 'Cihaz Bilgileri';
      case ReportSectionType.serviceTimes:
        return 'Servis Zamanları';
      case ReportSectionType.problemDetails:
        return 'Problem Detayları';
      case ReportSectionType.actionsTaken:
        return 'Yapılan İşlemler';
      case ReportSectionType.finalStatus:
        return 'Final Durum';
      case ReportSectionType.spareParts:
        return 'Kullanılan Parçalar';
      case ReportSectionType.signatures:
        return 'İmzalar';
      case ReportSectionType.maintenancePeriod:
        return 'Bakım Periyodu';
      case ReportSectionType.notes:
        return 'Notlar ve Öneriler';
      case ReportSectionType.technicianInfo:
        return 'Teknisyen Bilgileri';
    }
  }
}

/// Rapor bölümü modeli
@HiveType(typeId: 29)
class ReportSection {
  @HiveField(0)
  ReportSectionType type; // Bölüm tipi

  @HiveField(1)
  bool isVisible; // Görünür mü?

  @HiveField(2)
  int order; // Sıra numarası

  @HiveField(3)
  String? title; // Özel başlık (null ise varsayılan)

  @HiveField(4)
  bool isRequired; // Zorunlu alan mı?

  ReportSection({
    required this.type,
    this.isVisible = true,
    required this.order,
    this.title,
    this.isRequired = false,
  });
}

/// Rapor stil ayarları
@HiveType(typeId: 30)
class ReportStyle {
  @HiveField(0)
  int primaryColor; // Ana renk (0xFF2C3E50 gibi)

  @HiveField(1)
  int secondaryColor; // İkincil renk

  @HiveField(2)
  int accentColor; // Vurgu rengi

  @HiveField(3)
  String fontFamily; // Yazı tipi

  @HiveField(4)
  String companyName; // Şirket adı

  @HiveField(5)
  bool showLogo; // Logo gösterilsin mi?

  @HiveField(6)
  String? logoPath; // Logo dosya yolu (varsa)

  @HiveField(7)
  LogoPosition logoPosition; // Logo pozisyonu

  @HiveField(8)
  bool showTechnician; // Teknisyen bilgisi gösterilsin mi?

  @HiveField(9)
  bool showCompanyDetails; // Firma detayları gösterilsin mi?

  ReportStyle({
    this.primaryColor = 0xFF2C3E50,
    this.secondaryColor = 0xFFECF0F1,
    this.accentColor = 0xFF3498DB,
    this.fontFamily = 'OpenSans',
    this.companyName = 'COMPANY NAME',
    this.showLogo = true,
    this.logoPath,
    this.logoPosition = LogoPosition.top,
    this.showTechnician = true,
    this.showCompanyDetails = true,
  });
}

/// Rapor görünüm şekli (Layout tipi)
@HiveType(typeId: 43)
enum ReportLayoutType {
  @HiveField(0)
  classic, // Klasik - Üstte firma bilgileri
  @HiveField(1)
  modern, // Modern - Sol sidebar
  @HiveField(2)
  minimal, // Minimal - Sadece gerekli bilgiler
  @HiveField(3)
  professional, // Profesyonel - Detaylı header
  @HiveField(4)
  compact, // Kompakt - Yer tasarruflu
}

/// Logo pozisyonu
@HiveType(typeId: 44)
enum LogoPosition {
  @HiveField(0)
  top, // Üst orta
  @HiveField(1)
  left, // Sol üst
  @HiveField(2)
  right, // Sağ üst
  @HiveField(3)
  center, // Tam orta
}
