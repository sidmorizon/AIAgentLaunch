import AppKit
import SwiftUI

@main
struct AIAgentLaunchApp: App {
    var body: some Scene {
        MenuBarExtra("AIAgentLaunch", systemImage: "bolt.circle") {
            MenuBarContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
