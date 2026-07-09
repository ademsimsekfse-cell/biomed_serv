import 'package:flutter/material.dart';

/// Responsive design için yardımcı sınıf
/// Tüm platformlara (mobil, tablet, masaüstü) uyarlanabilir UI oluşturmak için kullanılır

/// Cihaz türünü belirler
enum DeviceSize { mobile, tablet, desktop }

class ResponsiveUtils {
  static const double _mobileThreshold = 600;
  static const double _tabletThreshold = 1200;

  // Private constructor - utility sınıf
  ResponsiveUtils._();

  /// Ekran genişliğine göre cihaz türünü döndürür
  static DeviceSize getDeviceSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth < _mobileThreshold) {
      return DeviceSize.mobile;
    } else if (screenWidth < _tabletThreshold) {
      return DeviceSize.tablet;
    } else {
      return DeviceSize.desktop;
    }
  }

  /// Ekranın genişliğini döndürür
  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// Ekranın yüksekliğini döndürür
  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  /// Cihazın mobil olup olmadığını kontrol eder
  static bool isMobile(BuildContext context) {
    return getDeviceSize(context) == DeviceSize.mobile;
  }

  /// Cihazın tablet olup olmadığını kontrol eder
  static bool isTablet(BuildContext context) {
    return getDeviceSize(context) == DeviceSize.tablet;
  }

  /// Cihazın masaüstü olup olmadığını kontrol eder
  static bool isDesktop(BuildContext context) {
    return getDeviceSize(context) == DeviceSize.desktop;
  }

  /// Grid column sayısını belirler
  static int getGridColumns(BuildContext context) {
    return switch (getDeviceSize(context)) {
      DeviceSize.mobile => 1,
      DeviceSize.tablet => 2,
      DeviceSize.desktop => 3,
    };
  }

  /// Padding değerini belirler
  static EdgeInsets getScreenPadding(BuildContext context) {
    return switch (getDeviceSize(context)) {
      DeviceSize.mobile => const EdgeInsets.all(12.0),
      DeviceSize.tablet => const EdgeInsets.all(16.0),
      DeviceSize.desktop => const EdgeInsets.all(24.0),
    };
  }

  /// Font size'ı ayarlar
  static double getTitleFontSize(BuildContext context) {
    return switch (getDeviceSize(context)) {
      DeviceSize.mobile => 18.0,
      DeviceSize.tablet => 20.0,
      DeviceSize.desktop => 24.0,
    };
  }

  /// Subtitle font size'ı ayarlar
  static double getSubtitleFontSize(BuildContext context) {
    return switch (getDeviceSize(context)) {
      DeviceSize.mobile => 14.0,
      DeviceSize.tablet => 15.0,
      DeviceSize.desktop => 16.0,
    };
  }

  /// Body text font size'ı ayarlar
  static double getBodyFontSize(BuildContext context) {
    return switch (getDeviceSize(context)) {
      DeviceSize.mobile => 12.0,
      DeviceSize.tablet => 13.0,
      DeviceSize.desktop => 14.0,
    };
  }

  /// Small text font size'ı ayarlar
  static double getSmallFontSize(BuildContext context) {
    return switch (getDeviceSize(context)) {
      DeviceSize.mobile => 10.0,
      DeviceSize.tablet => 11.0,
      DeviceSize.desktop => 12.0,
    };
  }

  /// Icon size'ı ayarlar
  static double getIconSize(BuildContext context) {
    return switch (getDeviceSize(context)) {
      DeviceSize.mobile => 20.0,
      DeviceSize.tablet => 24.0,
      DeviceSize.desktop => 28.0,
    };
  }

  /// Large icon size'ı ayarlar
  static double getLargeIconSize(BuildContext context) {
    return switch (getDeviceSize(context)) {
      DeviceSize.mobile => 32.0,
      DeviceSize.tablet => 40.0,
      DeviceSize.desktop => 48.0,
    };
  }

  /// Button height'ı ayarlar
  static double getButtonHeight(BuildContext context) {
    return switch (getDeviceSize(context)) {
      DeviceSize.mobile => 44.0,
      DeviceSize.tablet => 48.0,
      DeviceSize.desktop => 52.0,
    };
  }

  /// List tile height'ı ayarlar
  static double getListTileHeight(BuildContext context) {
    return switch (getDeviceSize(context)) {
      DeviceSize.mobile => 56.0,
      DeviceSize.tablet => 64.0,
      DeviceSize.desktop => 72.0,
    };
  }

  /// Maksimum content width (masaüstü için)
  static double getMaxContentWidth(BuildContext context) {
    return switch (getDeviceSize(context)) {
      DeviceSize.mobile => double.infinity,
      DeviceSize.tablet => 600.0,
      DeviceSize.desktop => 1000.0,
    };
  }

  /// Orientation'ı kontrol eder (portrait/landscape)
  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }

  /// Landscape mod mu kontrol eder
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  /// Device pixel ratio (çözünürlük) döndürür
  static double getDevicePixelRatio(BuildContext context) {
    return MediaQuery.of(context).devicePixelRatio;
  }

  /// Safe area padding'i döndürür
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    return MediaQuery.of(context).padding;
  }

  /// View insets'i döndürür (klavye açık olduğunda)
  static EdgeInsets getViewInsets(BuildContext context) {
    return MediaQuery.of(context).viewInsets;
  }
}

/// Responsive Builder Widget - cihaz türüne göre farklı UI oluşturur
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext, DeviceSize) builder;

  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final deviceSize = ResponsiveUtils.getDeviceSize(context);
    return builder(context, deviceSize);
  }
}

/// Orientation Builder Widget - orientation değişikliklerine göre rebuild eder
class OrientationBuilder extends StatelessWidget {
  final Widget Function(BuildContext, Orientation) builder;

  const OrientationBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, MediaQuery.of(context).orientation);
  }
}

