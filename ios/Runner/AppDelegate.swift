import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // Flutter plugin kaydı
    GeneratedPluginRegistrant.register(with: self)
    
    // Bildirim izinleri iste
    UNUserNotificationCenter.current().delegate = self
    requestNotificationPermissions()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // MARK: - Bildirim İzinleri
  private func requestNotificationPermissions() {
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .badge, .sound]
    ) { granted, error in
      if let error = error {
        print("Bildirim izin hatası: \(error.localizedDescription)")
      } else {
        print("Bildirim izni: \(granted ? "Verildi" : "Reddedildi")")
      }
    }
  }
  
  // MARK: - Uygulama Yaşam Döngüsü
  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    // Uygulama aktif olduğunda yapılacaklar
  }
  
  override func applicationWillResignActive(_ application: UIApplication) {
    super.applicationWillResignActive(application)
    // Uygulama arka plana geçerken yapılacaklar
  }
  
  // MARK: - UNUserNotificationCenterDelegate
  // Ön planda bildirim gösterimi için
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // iOS 14+ için .banner, iOS 13 için .alert
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .badge, .sound])
    } else {
      completionHandler([.alert, .badge, .sound])
    }
  }
  
  // Bildirim tıklama işleme
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    print("Bildirim tıklandı: \(userInfo)")
    completionHandler()
  }
}
