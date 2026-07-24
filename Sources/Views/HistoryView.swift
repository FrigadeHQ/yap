import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Transcript.createdAt, order: .reverse) private var transcripts: [Transcript]
    @State private var search = ""
    var onBack: (() -> Void)?

    private var filtered: [Transcript] {
        guard !search.isEmpty else { return transcripts }
        return transcripts.filter { $0.text.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let onBack {
                PageHeader(title: "History", onBack: onBack)
                Divider().overlay(Theme.hairline)
            }
            toolbar
            Divider().overlay(Theme.hairline)

            if filtered.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: Theme.s2) {
                        ForEach(filtered) { transcript in
                            TranscriptRow(transcript: transcript) {
                                context.delete(transcript)
                                try? context.save()
                            }
                        }
                    }
                    .padding(Theme.s4)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var toolbar: some View {
        HStack(spacing: Theme.s3) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
            TextField("Search transcripts", text: $search)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
            Spacer()
            if !transcripts.isEmpty {
                Button("Clear all") {
                    for transcript in transcripts { context.delete(transcript) }
                    try? context.save()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, Theme.s4)
        .padding(.vertical, Theme.s3)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.s3) {
            Image(systemName: "text.bubble")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.tertiary)
            Text(search.isEmpty ? "No transcripts yet" : "No matches")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            if search.isEmpty {
                Text("Press your shortcut and start talking.")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct TranscriptRow: View {
    let transcript: Transcript
    let onDelete: () -> Void

    @State private var hovering = false
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s2) {
            Text(transcript.text)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)

            HStack(spacing: Theme.s2) {
                Text(transcript.createdAt, format: .relative(presentation: .named))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                if let device = transcript.inputDeviceName {
                    Text("·").foregroundStyle(.tertiary)
                    Text(device).font(.system(size: 11)).foregroundStyle(.tertiary).lineLimit(1)
                }
                Spacer()

                if hovering || copied {
                    Button(action: copy) {
                        Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .labelStyle(.titleAndIcon)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(copied ? Theme.success : .secondary)

                    Button(action: onDelete) {
                        Image(systemName: "trash").font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(Theme.s3)
        .background(hovering ? Theme.surfaceHover : Theme.surface,
                    in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(transcript.text, forType: .string)
        copied = true
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            copied = false
        }
    }
}
