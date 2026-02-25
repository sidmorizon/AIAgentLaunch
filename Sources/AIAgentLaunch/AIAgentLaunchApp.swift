import AppKit
import SwiftUI

@main
struct AIAgentLaunchApp: App {
    var body: some Scene {
        MenuBarExtra("Agent Launcher", systemImage: "bolt.circle") {
            MenuBarContentView()
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
