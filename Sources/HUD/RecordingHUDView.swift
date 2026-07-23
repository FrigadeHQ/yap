import SwiftUI

/// The floating recording HUD: a quiet card showing that Yap is listening, a
/// live level meter, a preview of the running transcript, and controls to
/// finish or discard.
struct RecordingHUDView: View {
    @Bindable var model: HUDModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s3) {
            HStack(spacing: Theme.s3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                if model.phase == .listening {
                    LevelMeter(level: model.level)
                }

                Spacer(minLength: Theme.s3)

                if model.phase == .listening {
                    HUDButton(systemName: "xmark", tint: .secondary) {
                        model.onCancel?()
                    }
                    .help("Discard")

                    HUDButton(systemName: "checkmark", tint: Theme.success, prominent: true) {
                        model.onConfirm?()
                    }
                    .help("Finish and insert")
                }
            }

            if !model.partial.isEmpty, model.phase != .restarting {
                Text(model.partial)
                    .font(.system(size: 12.5))
                    // Full-strength primary: on a translucent panel, .secondary
                    // over a light backdrop is effectively invisible.
                    .foregroundStyle(.primary.opacity(0.85))
                    .lineLimit(2)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, Theme.s4)
        .padding(.vertical, Theme.s3 + 2)
        .frame(width: 380, alignment: .leading)
        .background {
            // Regular (not ultraThin) material plus a tint, so text stays legible
            // over both light and dark backdrops.
            ZStack {
                RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                    .fill(.regularMaterial)
                RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.5))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                .strokeBorder(Theme.hairlineStrong, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 24, y: 10)
        .animation(.easeInOut(duration: 0.18), value: model.phase)
    }

    private var title: String {
        switch model.phase {
        case .listening: return "Listening"
        case .transcribing: return "Transcribing…"
        case .restarting: return "Restarting Yap"
        }
    }
}

/// A small circular control sized for the HUD.
private struct HUDButton: View {
    let systemName: String
    var tint: Color = .secondary
    var prominent: Bool = false
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(prominent ? Color.white : tint)
                .frame(width: 24, height: 24)
                .background {
                    Circle().fill(
                        prominent
                            ? Theme.success.opacity(hovering ? 1.0 : 0.9)
                            : Color.primary.opacity(hovering ? 0.14 : 0.08)
                    )
                }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

/// A row of bars that track the live audio level.
private struct LevelMeter: View {
    let level: Float
    private let barCount = 7
    private let minHeight: CGFloat = 3
    private let maxHeight: CGFloat = 20

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    .fill(Color.primary.opacity(0.8))
                    .frame(width: 3, height: height(for: index))
            }
        }
        .frame(height: maxHeight)
        // Short spring reads as organic motion rather than a stepping meter.
        .animation(.spring(response: 0.16, dampingFraction: 0.62), value: level)
    }

    private func height(for index: Int) -> CGFloat {
        // Centre bars react most, edges least, so it moves like a waveform.
        let centre = Double(barCount - 1) / 2
        let distance = abs(Double(index) - centre) / centre
        let weight = 1.0 - distance * 0.55
        let scaled = Double(level) * weight
        return minHeight + (maxHeight - minHeight) * CGFloat(scaled)
    }
}
