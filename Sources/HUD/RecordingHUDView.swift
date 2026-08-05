import SwiftUI

struct RecordingHUDView: View {
    @Bindable var model: HUDModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s3) {
            HStack(spacing: Theme.s3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(model.phase == .confirmCancel ? Theme.recording : .primary)
                    .fixedSize(horizontal: true, vertical: false)

                if let language = model.language, model.phase != .restarting {
                    LanguageTag(text: language)
                }

                if isRecordingPhase {
                    // The row is a fixed width, so the tag has to come out of
                    // somewhere. A slightly shorter trace costs less than pushing
                    // the confirm and cancel buttons off the card.
                    Waveform(
                        levels: model.levels,
                        bars: model.language == nil ? Waveform.bars : Waveform.barsBesideLanguageTag
                    )
                }

                if isProcessingPhase {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                }

                Spacer(minLength: Theme.s2)

                if isRecordingPhase {
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
                    // Full-strength primary: .secondary is invisible over a light backdrop on translucent material.
                    .foregroundStyle(.primary.opacity(0.85))
                    .lineLimit(2)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, Theme.s4)
        .padding(.vertical, Theme.s3)
        .frame(width: 348, alignment: .leading)
        .background {
            // Regular (not ultraThin) material plus a tint, so text stays legible over light and dark backdrops.
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
        .shadow(color: .black.opacity(0.22), radius: 22, y: 8)
        // Transparent margin so the shadow can fall off inside the window instead
        // of being clipped square. The bottom needs more room than the top because
        // the shadow is offset downward and the blur tails past its nominal radius.
        .padding(Self.shadowInsets)
        .animation(.easeInOut(duration: 0.18), value: model.phase)
    }

    static let shadowInsets = EdgeInsets(top: 28, leading: 34, bottom: 54, trailing: 34)

    private var isRecordingPhase: Bool {
        model.phase == .listening || model.phase == .confirmCancel
    }

    // Working states with no waveform, so a spinner shows they're still running.
    private var isProcessingPhase: Bool {
        model.phase == .transcribing || model.phase == .cleaning
    }

    private var title: String {
        switch model.phase {
        case .listening: return "Listening"
        case .confirmCancel: return "Press esc again to cancel"
        case .transcribing: return "Transcribing…"
        case .cleaning: return "Cleaning up…"
        case .restarting: return "Restarting Yap"
        }
    }
}

/// Which language is listening, for people who dictate in more than one. Small
/// enough to read past without noticing when there is only ever one answer.
private struct LanguageTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.4)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.primary.opacity(0.08)))
            .fixedSize()
    }
}

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

/// A scrolling waveform. Each bar is one moment in time — newest on the right,
/// older samples drifting left — so speech leaves a visible trace instead of the
/// whole meter rising and falling as one.
private struct Waveform: View {
    let levels: [Float]
    /// Trimmed from the oldest end, so the newest sample stays at the right edge
    /// however much room the rest of the row leaves.
    let bars: Int

    static let bars = HUDModel.waveformSampleCount
    /// Ten bars is a shade more than the tag needs, so the row keeps a little slack.
    static let barsBesideLanguageTag = HUDModel.waveformSampleCount - 10

    private let barWidth: CGFloat = 2.5
    private let spacing: CGFloat = 2
    private let minHeight: CGFloat = 2.5
    private let maxHeight: CGFloat = 22

    var body: some View {
        let visible = Array(levels.suffix(bars))
        HStack(alignment: .center, spacing: spacing) {
            ForEach(Array(visible.enumerated()), id: \.offset) { index, level in
                Capsule()
                    .fill(Color.primary.opacity(opacity(for: index, of: visible.count)))
                    .frame(width: barWidth, height: height(for: level))
            }
        }
        .frame(height: maxHeight)
        // Just enough to smooth the step between samples without adding lag.
        .animation(.easeOut(duration: 0.06), value: visible)
    }

    private func height(for level: Float) -> CGFloat {
        minHeight + (maxHeight - minHeight) * CGFloat(max(0, min(1, level)))
    }

    /// Older samples fade out, which gives the trace a sense of direction.
    private func opacity(for index: Int, of count: Int) -> Double {
        guard count > 1 else { return 0.85 }
        let age = Double(index) / Double(count - 1)
        return 0.28 + 0.57 * age
    }
}
