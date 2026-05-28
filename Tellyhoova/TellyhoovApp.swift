import SwiftUI
import AppKit
import UserNotifications

@main
struct TellyhoovApp: App {
    init() {
        NSApplication.shared.applicationIconImage = NSImage(named: "AppIcon")
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        Window("Tellyhoova 📺", id: "main") {
            ContentView()
                .onAppear {
                    NSApplication.shared.windows.first {
                        $0.identifier?.rawValue == "main" || $0.title.contains("Tellyhoova")
                    }?.backgroundColor = NSColor(calibratedRed: 26/255.0, green: 58/255.0, blue: 92/255.0, alpha: 1)
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 520, height: 520)
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView()
        }
    }
}

private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
