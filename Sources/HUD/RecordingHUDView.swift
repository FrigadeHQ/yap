import SwiftUI

/// The floating recording HUD. Minimal and quiet: a soft material card with a
/// status glyph, a live level meter while listening, and an optional preview of
/// the in-progress transcript.
struct RecordingHUDView: View {
    @Bindable var model: HUDModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s3) {
            HStack(spacing: Theme.s3) {
                statusGlyph
                statusContent
                Spacer(minLength: 0)
            }

            if showsPartial {
                Text(model.partial)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, Theme.s4)
        .padding(.vertical, Theme.s3 + 2)
        .frame(width: 340, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 20, y: 8)
        .animation(.easeInOut(duration: 0.2), value: model.phase)
        .animation(.easeInOut(duration: 0.2), value: showsPartial)
    }

    // MARK: - Pieces

    @ViewBuilder
    private var statusGlyph: some View {
        switch model.phase {
        case .listening:
            RecordingDot()
        case .transcribing:
            ProgressView()
                .controlSize(.small)
                .frame(width: 18, height: 18)
        case .done(let inserted):
            Image(systemName: inserted ? "checkmark.circle.fill" : "doc.on.clipboard")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(inserted ? Theme.success : .secondary)
        case .empty:
            Image(systemName: "waveform.slash")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var statusContent: some View {
        switch model.phase {
        case .listening:
            HStack(spacing: Theme.s3) {
                Text("Listening")
                    .font(.system(size: 13, weight: .semibold))
                LevelMeter(level: model.level)
            }
        case .transcribing:
            Text("Transcribing…")
                .font(.system(size: 13, weight: .semibold))
        case .done(let inserted):
            Text(inserted ? "Inserted" : "Copied — paste manually")
                .font(.system(size: 13, weight: .semibold))
        case .empty:
            Text("Didn't catch that")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var showsPartial: Bool {
        if case .listening = model.phase, !model.partial.isEmpty { return true }
        return false
    }
}

/// A softly pulsing dot indicating live recording.
private struct RecordingDot: View {
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(Theme.recording)
            .frame(width: 10, height: 10)
            .overlay(
                Circle()
                    .stroke(Theme.recording.opacity(0.5), lineWidth: 6)
                    .scaleEffect(pulse ? 1.9 : 1.0)
                    .opacity(pulse ? 0 : 0.6)
            )
            .frame(width: 18, height: 18)
            .onAppear {
                withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) {
                    pulse = true
                }
            }
    }
}

/// A row of thin bars that respond to the live audio level.
private struct LevelMeter: View {
    let level: Float
    private let barCount = 5

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    .fill(Color.primary.opacity(0.75))
                    .frame(width: 3, height: height(for: index))
            }
        }
        .frame(height: 18)
        .animation(.easeOut(duration: 0.12), value: level)
    }

    private func height(for index: Int) -> CGFloat {
        // Center bars react more than the edges, for an organic look.
        let center = Double(barCount - 1) / 2
        let distance = abs(Double(index) - center) / center
        let weight = 1.0 - distance * 0.5
        let base: CGFloat = 4
        let span: CGFloat = 14
        return base + span * CGFloat(Double(level) * weight)
    }
}
