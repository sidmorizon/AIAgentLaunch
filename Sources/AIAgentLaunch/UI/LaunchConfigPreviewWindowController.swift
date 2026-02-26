import AppKit
import SwiftUI

private enum LaunchConfigPreviewWindowLayout {
    static let initialSize = NSSize(width: 560, height: 420)
    static let minimumSize = NSSize(width: 430, height: 320)
}

@MainActor
final class LaunchConfigPreviewWindowController: ObservableObject {
    private var previewWindow: NSWindow?

    func present(launchLogText: String) {
        guard !launchLogText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let window = previewWindow ?? makeWindow()
        window.contentView = NSHostingView(
            rootView: LaunchConfigPreviewWindow(
                launchLogText: launchLogText,
                onClose: { [weak self] in
                    self?.close()
                }
            )
        )
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func close() {
        previewWindow?.orderOut(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: LaunchConfigPreviewWindowLayout.initialSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Agent 启动日志"
        window.minSize = LaunchConfigPreviewWindowLayout.minimumSize
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.center()
        previewWindow = window
        return window
    }
}

private struct LaunchConfigPreviewWindow: View {
    let launchLogText: String
    let onClose: () -> Void

    var body: some View {
        MenuBarSheetContainer(title: "Agent 启动日志", systemImage: "doc.plaintext") {
            ScrollView {
                Text(launchLogText)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )

            HStack {
                Spacer()
                Button("关闭", action: onClose)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .frame(
            minWidth: LaunchConfigPreviewWindowLayout.minimumSize.width,
            minHeight: LaunchConfigPreviewWindowLayout.minimumSize.height
        )
    }
}
