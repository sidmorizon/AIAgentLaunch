import AppKit
import SwiftUI

@main
struct AIAgentLaunchApp: App {
    @StateObject private var launchConfigPreviewWindowController = LaunchConfigPreviewWindowController()
    @StateObject private var profileManagementWindowController = APIProfileManagementWindowController()

    var body: some Scene {
        MenuBarExtra("AIAgentLaunch", systemImage: "bolt.circle") {
            MenuBarContentView(
                launchConfigPreviewWindowController: launchConfigPreviewWindowController,
                profileManagementWindowController: profileManagementWindowController
            )
        }
        .menuBarExtraStyle(.window)
    }
}
