import SwiftUI

enum MenuBarUITokens {
    static let panelWidth: CGFloat = 388
    static let panelCornerRadius: CGFloat = 14
    static let sectionSpacing: CGFloat = 10
    static let fieldSpacing: CGFloat = 6
}

struct MenuBarPanel<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MenuBarUITokens.sectionSpacing) {
            content
        }
        .padding(14)
        .frame(width: MenuBarUITokens.panelWidth)
        .background(
            RoundedRectangle(cornerRadius: MenuBarUITokens.panelCornerRadius, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: MenuBarUITokens.panelCornerRadius, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 9, x: 0, y: 3)
    }
}

struct MenuBarSection<Content: View>: View {
    private let title: String
    private let systemImage: String
    private let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: MenuBarUITokens.fieldSpacing) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
        }
    }
}

struct MenuBarField<Content: View>: View {
    private let title: String
    private let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content
        }
    }
}

struct MenuBarValidationText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.red)
    }
}

enum MenuBarBadgeTone {
    case neutral
    case info
    case success
    case warning
    case error

    var foregroundColor: Color {
        switch self {
        case .neutral:
            return .secondary
        case .info:
            return Color(red: 0.13, green: 0.48, blue: 0.84)
        case .success:
            return Color(red: 0.11, green: 0.52, blue: 0.29)
        case .warning:
            return Color(red: 0.80, green: 0.45, blue: 0.10)
        case .error:
            return Color(red: 0.70, green: 0.16, blue: 0.14)
        }
    }

    var backgroundColor: Color {
        switch self {
        case .neutral:
            return Color.secondary.opacity(0.10)
        case .info:
            return Color(red: 0.87, green: 0.93, blue: 0.99)
        case .success:
            return Color(red: 0.90, green: 0.96, blue: 0.90)
        case .warning:
            return Color(red: 0.99, green: 0.95, blue: 0.88)
        case .error:
            return Color(red: 0.99, green: 0.91, blue: 0.90)
        }
    }

    var symbolName: String {
        switch self {
        case .neutral:
            return "info.circle"
        case .info:
            return "info.circle.fill"
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }
}

struct MenuBarStatusBadge: View {
    let text: String
    let tone: MenuBarBadgeTone

    var body: some View {
        Label(text, systemImage: tone.symbolName)
            .font(.caption)
            .foregroundStyle(tone.foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(tone.backgroundColor)
            )
    }
}

struct MenuBarSheetContainer<Content: View>: View {
    private let title: String
    private let systemImage: String
    private let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(16)
    }
}
