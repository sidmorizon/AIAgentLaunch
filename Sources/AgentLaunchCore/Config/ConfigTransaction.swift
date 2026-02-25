import Foundation

public final class ConfigTransaction {
    public enum OriginalState {
        case absent
        case content(String)
    }

    private var originalState: OriginalState?
    private var restored = false
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func applyTemporaryConfiguration(_ temporaryConfiguration: String, at configurationFilePath: URL) throws {
        if originalState == nil {
            if fileManager.fileExists(atPath: configurationFilePath.path) {
                let originalConfiguration = try String(contentsOf: configurationFilePath, encoding: .utf8)
                originalState = .content(originalConfiguration)
            } else {
                originalState = .absent
            }
        }

        restored = false
        try fileManager.createDirectory(at: configurationFilePath.deletingLastPathComponent(), withIntermediateDirectories: true)
        try temporaryConfiguration.write(to: configurationFilePath, atomically: true, encoding: .utf8)
    }

    public func restoreOriginalConfiguration(at configurationFilePath: URL) throws {
        guard !restored else { return }
        guard let originalState else { return }

        switch originalState {
        case .absent:
            if fileManager.fileExists(atPath: configurationFilePath.path) {
                try fileManager.removeItem(at: configurationFilePath)
            }
        case .content(let originalConfiguration):
            try fileManager.createDirectory(at: configurationFilePath.deletingLastPathComponent(), withIntermediateDirectories: true)
            try originalConfiguration.write(to: configurationFilePath, atomically: true, encoding: .utf8)
        }

        restored = true
    }
}
