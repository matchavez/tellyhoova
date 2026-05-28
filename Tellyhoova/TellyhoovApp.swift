import SwiftUI
import AppKit

@main
struct TellyhoovApp: App {
    init() {
        NSApplication.shared.applicationIconImage = NSImage(named: "AppIcon")
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
