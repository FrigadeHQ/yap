import SwiftUI

/// A shadcn-like design token set.
enum Theme {
    static let radiusLarge: CGFloat = 16
    static let radius: CGFloat = 12
    static let radiusSmall: CGFloat = 8

    static let hairline = Color.primary.opacity(0.08)
    static let hairlineStrong = Color.primary.opacity(0.14)
    static let surface = Color.primary.opacity(0.035)
    static let surfaceHover = Color.primary.opacity(0.06)

    static let recording = Color(red: 0.90, green: 0.29, blue: 0.35)
    static let success = Color(red: 0.20, green: 0.68, blue: 0.45)

    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 28
}

struct Card<Content: View>: View {
    var padding: CGFloat = Theme.s4
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
    }
}

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(.tertiary)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .foregroundStyle(Color(nsColor: .windowBackgroundColor))
            .background(Color.primary.opacity(configuration.isPressed ? 0.75 : 0.9),
                        in: RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .foregroundStyle(.primary)
            .background(configuration.isPressed ? Theme.surfaceHover : Theme.surface,
                        in: RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
            .contentShape(Rectangle())
    }
}
