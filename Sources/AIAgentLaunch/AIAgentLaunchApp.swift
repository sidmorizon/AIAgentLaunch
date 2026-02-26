import AppKit
import SwiftUI

@main
struct AIAgentLaunchApp: App {
    @StateObject private var launchConfigPreviewWindowController = LaunchConfigPreviewWindowController()

    var body: some Scene {
        MenuBarExtra("AIAgentLaunch", systemImage: "bolt.circle") {
            MenuBarContentView(launchConfigPreviewWindowController: launchConfigPreviewWindowController)
        }
        .menuBarExtraStyle(.window)
    }
}
