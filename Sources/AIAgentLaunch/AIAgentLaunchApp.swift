import AppKit
import SwiftUI

@main
struct AIAgentLaunchApp: App {
    var body: some Scene {
        MenuBarExtra("Agent Launcher", systemImage: "bolt.circle") {
            MenuBarContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
