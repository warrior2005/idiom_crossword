import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let dailyReminderChannelName = "idiom_crossword/daily_reminder"
  private static let dailyReminderIdentifier = "daily_challenge_reminder"
  private var dailyReminderChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: Self.dailyReminderChannelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "unavailable", message: "App delegate unavailable", details: nil))
        return
      }
      self.handleDailyReminderCall(call, result: result)
    }
    dailyReminderChannel = channel
  }

  private func handleDailyReminderCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let center = UNUserNotificationCenter.current()
    switch call.method {
    case "authorizationStatus":
      center.getNotificationSettings { settings in
        self.complete(result, value: self.authorizationName(settings.authorizationStatus))
      }
    case "requestAuthorization":
      center.requestAuthorization(options: [.alert, .sound]) { _, error in
        if let error {
          self.complete(
            result,
            value: FlutterError(
              code: "authorization_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
          return
        }
        center.getNotificationSettings { settings in
          self.complete(result, value: self.authorizationName(settings.authorizationStatus))
        }
      }
    case "scheduleDaily":
      guard
        let arguments = call.arguments as? [String: Any],
        let hour = arguments["hour"] as? Int,
        let minute = arguments["minute"] as? Int,
        (0...23).contains(hour),
        (0...59).contains(minute)
      else {
        result(FlutterError(code: "invalid_time", message: "Invalid reminder time", details: nil))
        return
      }
      let content = UNMutableNotificationContent()
      content.title = "每日挑战"
      content.body = "今日挑战已更新，来完成今天的成语填字吧。"
      content.sound = .default
      var dateComponents = DateComponents()
      dateComponents.calendar = Calendar.current
      dateComponents.hour = hour
      dateComponents.minute = minute
      let trigger = UNCalendarNotificationTrigger(
        dateMatching: dateComponents,
        repeats: true
      )
      let request = UNNotificationRequest(
        identifier: Self.dailyReminderIdentifier,
        content: content,
        trigger: trigger
      )
      center.add(request) { error in
        if let error {
          self.complete(
            result,
            value: FlutterError(
              code: "schedule_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        } else {
          self.complete(result, value: nil)
        }
      }
    case "cancelDaily":
      center.removePendingNotificationRequests(
        withIdentifiers: [Self.dailyReminderIdentifier]
      )
      result(nil)
    case "openSettings":
      let settingsUrl: String
      if #available(iOS 16.0, *) {
        settingsUrl = UIApplication.openNotificationSettingsURLString
      } else if #available(iOS 15.4, *) {
        settingsUrl = UIApplicationOpenNotificationSettingsURLString
      } else {
        settingsUrl = UIApplication.openSettingsURLString
      }
      guard let url = URL(string: settingsUrl) else {
        result(false)
        return
      }
      UIApplication.shared.open(url, options: [:]) { opened in
        result(opened)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func authorizationName(_ status: UNAuthorizationStatus) -> String {
    switch status {
    case .notDetermined: return "notDetermined"
    case .denied: return "denied"
    case .authorized: return "authorized"
    case .provisional: return "provisional"
    case .ephemeral: return "ephemeral"
    @unknown default: return "unsupported"
    }
  }

  private func complete(_ result: @escaping FlutterResult, value: Any?) {
    DispatchQueue.main.async {
      result(value)
    }
  }
}
