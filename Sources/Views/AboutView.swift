import SwiftUI

struct AboutView: View {
    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return short ?? "1.0"
    }

    var body: some View {
        VStack(spacing: Theme.s4) {
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 72, height: 72)
            }

            VStack(spacing: Theme.s1) {
                Text("Yap")
                    .font(.system(size: 20, weight: .bold))
                Text("On-device dictation for macOS")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Text("Version \(version)")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Text("Yap transcribes your speech entirely on your Mac using Apple's Speech framework. No audio ever leaves your machine, and there is no account, API key, or subscription.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Theme.s2)

            Divider().overlay(Theme.hairline)

            VStack(spacing: Theme.s2) {
                Link("View source on GitHub", destination: URL(string: "https://github.com/FrigadeHQ/yap")!)
                    .font(.system(size: 12, weight: .medium))
                Text("Released under the MIT License.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)

            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Text("Built by")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Link("Frigade", destination: URL(string: "https://frigade.com")!)
                        .font(.system(size: 11, weight: .medium))
                }
                Text("© 2026 Frigade, Inc.")
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
            }
        }
        .padding(Theme.s6)
        .frame(width: 360, height: 440)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
