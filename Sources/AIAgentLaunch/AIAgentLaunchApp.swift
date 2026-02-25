import AppKit
import SwiftUI

@main
struct AIAgentLaunchApp: App {
    var body: some Scene {
        MenuBarExtra("Agent Launcher", systemImage: "bolt.circle") {
            Text("Agent Launcher")
                .padding()
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
