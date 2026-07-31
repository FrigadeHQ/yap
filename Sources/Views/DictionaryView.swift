import SwiftUI

struct DictionaryView: View {
    @Environment(AppState.self) private var app
    let onBack: () -> Void

    @State private var newTerm = ""

    private var trimmed: String {
        newTerm.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "Dictionary", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.s4) {
                    Text("Teach Yap names and words it often gets wrong. It leans toward these when it hears them, and fixes first-letter slips like \u{201C}brigade\u{201D} to \u{201C}Frigade\u{201D} on device. With Clean up transcripts on, it also fixes messier mishearings.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: Theme.s2) {
                        TextField("Add a word or name", text: $newTerm)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .padding(.horizontal, Theme.s3)
                            .padding(.vertical, Theme.s2 + 2)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                                    .strokeBorder(Theme.hairline, lineWidth: 1)
                            )
                            .onSubmit(addTerm)

                        Button("Add", action: addTerm)
                            .disabled(trimmed.isEmpty)
                    }

                    if app.vocabulary.terms.isEmpty {
                        Text("No words yet. Add a name or term above.")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .padding(.top, Theme.s2)
                    } else {
                        Card(padding: Theme.s2) {
                            VStack(spacing: 0) {
                                ForEach(Array(app.vocabulary.terms.enumerated()), id: \.element) { index, term in
                                    if index > 0 {
                                        Divider().overlay(Theme.hairline).padding(.horizontal, Theme.s3)
                                    }
                                    HStack(spacing: Theme.s3) {
                                        Text(term).font(.system(size: 13))
                                        Spacer()
                                        Button {
                                            app.vocabulary.remove(term)
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                        .help("Remove")
                                    }
                                    .padding(.horizontal, Theme.s3)
                                    .padding(.vertical, Theme.s2 + 2)
                                }
                            }
                        }
                    }
                }
                .padding(Theme.s5)
            }
        }
    }

    private func addTerm() {
        app.vocabulary.add(newTerm)
        newTerm = ""
    }
}
