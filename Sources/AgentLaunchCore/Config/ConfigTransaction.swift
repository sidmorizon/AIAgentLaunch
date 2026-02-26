import Foundation

public final class ConfigTransaction {
    public enum OriginalState {
        case absent
        case content(String)
    }

    private var originalState: OriginalState?
    private var restored = false
    private let fileManager: FileManager

    private struct AssignmentLine {
        let key: String
        let line: String
    }

    private struct TemporaryConfigLayout {
        var topLevelAssignments: [AssignmentLine]
        var sectionAssignments: [String: [AssignmentLine]]
        var sectionOrder: [String]
        var sectionHeaderLines: [String: String]
    }

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func applyTemporaryConfiguration(_ temporaryConfiguration: String, at configurationFilePath: URL) throws -> String {
        let existingConfiguration: String?
        if originalState == nil {
            if fileManager.fileExists(atPath: configurationFilePath.path) {
                let originalConfiguration = try String(contentsOf: configurationFilePath, encoding: .utf8)
                originalState = .content(originalConfiguration)
                existingConfiguration = originalConfiguration
            } else {
                originalState = .absent
                existingConfiguration = nil
            }
        } else if fileManager.fileExists(atPath: configurationFilePath.path) {
            existingConfiguration = try String(contentsOf: configurationFilePath, encoding: .utf8)
        } else {
            existingConfiguration = nil
        }

        let mergedConfiguration = mergeConfiguration(
            existingConfiguration,
            with: temporaryConfiguration
        )
        restored = false
        try fileManager.createDirectory(at: configurationFilePath.deletingLastPathComponent(), withIntermediateDirectories: true)
        try mergedConfiguration.write(to: configurationFilePath, atomically: true, encoding: .utf8)
        return mergedConfiguration
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

    private func mergeConfiguration(_ existingConfiguration: String?, with temporaryConfiguration: String) -> String {
        let trimmedTemporaryConfiguration = temporaryConfiguration.trimmingCharacters(in: .newlines)
        guard let existingConfiguration else {
            return trimmedTemporaryConfiguration
        }
        let trimmedExistingConfiguration = existingConfiguration.trimmingCharacters(in: .newlines)
        guard !trimmedExistingConfiguration.isEmpty else {
            return trimmedTemporaryConfiguration
        }
        guard !trimmedTemporaryConfiguration.isEmpty else {
            return trimmedExistingConfiguration
        }

        let temporaryLayout = parseTemporaryConfigLayout(from: trimmedTemporaryConfiguration)
        let temporaryTopLevelKeys = Set(temporaryLayout.topLevelAssignments.map(\.key))

        var mergedLines: [String] = []
        var currentSectionName: String?
        var insertedTopLevelOverrides = false
        var appendedOverridesForSection = Set<String>()
        var seenSections = Set<String>()

        for line in normalizedLines(from: trimmedExistingConfiguration) {
            if let sectionName = parseSectionName(from: line) {
                if !insertedTopLevelOverrides {
                    appendTopLevelOverridesIfNeeded(
                        to: &mergedLines,
                        layout: temporaryLayout
                    )
                    insertedTopLevelOverrides = true
                }
                if let previousSectionName = currentSectionName {
                    appendSectionOverridesIfNeeded(
                        for: previousSectionName,
                        layout: temporaryLayout,
                        appendedSections: &appendedOverridesForSection,
                        to: &mergedLines
                    )
                }
                currentSectionName = sectionName
                seenSections.insert(sectionName)
                mergedLines.append(line)
                continue
            }

            if currentSectionName == nil,
               let topLevelKey = parseAssignmentKey(from: line),
               temporaryTopLevelKeys.contains(topLevelKey) {
                continue
            }

            if let sectionName = currentSectionName,
               let sectionAssignmentKey = parseAssignmentKey(from: line),
               sectionKeys(in: temporaryLayout, sectionName: sectionName).contains(sectionAssignmentKey) {
                continue
            }

            mergedLines.append(line)
        }

        if !insertedTopLevelOverrides {
            appendTopLevelOverridesIfNeeded(
                to: &mergedLines,
                layout: temporaryLayout
            )
            insertedTopLevelOverrides = true
        }

        if let finalSectionName = currentSectionName {
            appendSectionOverridesIfNeeded(
                for: finalSectionName,
                layout: temporaryLayout,
                appendedSections: &appendedOverridesForSection,
                to: &mergedLines
            )
        }

        for sectionName in temporaryLayout.sectionOrder where !seenSections.contains(sectionName) {
            appendMissingSection(
                sectionName,
                layout: temporaryLayout,
                to: &mergedLines
            )
        }

        let mergedConfiguration = dropTrailingEmptyLines(mergedLines).joined(separator: "\n")
        if mergedConfiguration.trimmingCharacters(in: .newlines).isEmpty {
            return trimmedTemporaryConfiguration
        }
        return mergedConfiguration
    }

    private func parseTemporaryConfigLayout(from configuration: String) -> TemporaryConfigLayout {
        var layout = TemporaryConfigLayout(
            topLevelAssignments: [],
            sectionAssignments: [:],
            sectionOrder: [],
            sectionHeaderLines: [:]
        )
        var currentSectionName: String?

        for line in normalizedLines(from: configuration) {
            if let sectionName = parseSectionName(from: line) {
                currentSectionName = sectionName
                if layout.sectionHeaderLines[sectionName] == nil {
                    layout.sectionOrder.append(sectionName)
                    layout.sectionHeaderLines[sectionName] = line
                }
                continue
            }

            guard let key = parseAssignmentKey(from: line) else { continue }
            let assignment = AssignmentLine(key: key, line: line)

            if let currentSectionName {
                var sectionLines = layout.sectionAssignments[currentSectionName] ?? []
                upsertAssignment(assignment, in: &sectionLines)
                layout.sectionAssignments[currentSectionName] = sectionLines
            } else {
                upsertAssignment(assignment, in: &layout.topLevelAssignments)
            }
        }
        return layout
    }

    private func upsertAssignment(_ assignment: AssignmentLine, in lines: inout [AssignmentLine]) {
        if let index = lines.firstIndex(where: { $0.key == assignment.key }) {
            lines[index] = assignment
            return
        }
        lines.append(assignment)
    }

    private func appendTopLevelOverridesIfNeeded(
        to mergedLines: inout [String],
        layout: TemporaryConfigLayout
    ) {
        for assignment in layout.topLevelAssignments {
            mergedLines.append(assignment.line)
        }
    }

    private func appendSectionOverridesIfNeeded(
        for sectionName: String,
        layout: TemporaryConfigLayout,
        appendedSections: inout Set<String>,
        to mergedLines: inout [String]
    ) {
        guard !appendedSections.contains(sectionName) else { return }
        guard let assignments = layout.sectionAssignments[sectionName], !assignments.isEmpty else { return }
        if let lastLine = mergedLines.last,
           !lastLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           parseSectionName(from: lastLine) != sectionName {
            mergedLines.append("")
        }
        for assignment in assignments {
            mergedLines.append(assignment.line)
        }
        appendedSections.insert(sectionName)
    }

    private func appendMissingSection(
        _ sectionName: String,
        layout: TemporaryConfigLayout,
        to mergedLines: inout [String]
    ) {
        guard let headerLine = layout.sectionHeaderLines[sectionName] else { return }
        guard let assignments = layout.sectionAssignments[sectionName], !assignments.isEmpty else { return }

        if !mergedLines.isEmpty,
           let lastLine = mergedLines.last,
           !lastLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            mergedLines.append("")
        }
        mergedLines.append(headerLine)
        for assignment in assignments {
            mergedLines.append(assignment.line)
        }
    }

    private func sectionKeys(in layout: TemporaryConfigLayout, sectionName: String) -> Set<String> {
        Set((layout.sectionAssignments[sectionName] ?? []).map(\.key))
    }

    private func normalizedLines(from text: String) -> [String] {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
    }

    private func dropTrailingEmptyLines(_ lines: [String]) -> [String] {
        var result = lines
        while let lastLine = result.last, lastLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.removeLast()
        }
        return result
    }

    private func parseSectionName(from line: String) -> String? {
        let trimmed = stripInlineComment(from: line).trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("["),
              trimmed.hasSuffix("]"),
              trimmed.count >= 3
        else {
            return nil
        }

        if trimmed.hasPrefix("[["),
           trimmed.hasSuffix("]]"),
           trimmed.count >= 5 {
            let start = trimmed.index(trimmed.startIndex, offsetBy: 2)
            let end = trimmed.index(trimmed.endIndex, offsetBy: -2)
            let name = trimmed[start..<end].trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : name
        }

        let start = trimmed.index(after: trimmed.startIndex)
        let end = trimmed.index(before: trimmed.endIndex)
        let name = trimmed[start..<end].trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    private func parseAssignmentKey(from line: String) -> String? {
        let trimmed = stripInlineComment(from: line).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("[") else { return nil }
        guard let equalIndex = trimmed.firstIndex(of: "=") else { return nil }
        let key = trimmed[..<equalIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }
        return key
    }

    private func stripInlineComment(from line: String) -> String {
        var isInsideDoubleQuotes = false
        var escaped = false
        var result = ""

        for character in line {
            if escaped {
                result.append(character)
                escaped = false
                continue
            }
            if character == "\\" {
                escaped = true
                result.append(character)
                continue
            }
            if character == "\"" {
                isInsideDoubleQuotes.toggle()
                result.append(character)
                continue
            }
            if character == "#", !isInsideDoubleQuotes {
                break
            }
            result.append(character)
        }
        return result
    }
}
