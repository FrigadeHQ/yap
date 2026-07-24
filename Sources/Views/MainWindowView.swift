import SwiftUI

enum MainPage: Equatable {
    case settings
    case history
}

struct MainWindowView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var app = app

        Group {
            switch app.mainPage {
            case .settings:
                SettingsView(onOpenHistory: { app.mainPage = .history })
            case .history:
                HistoryView(onBack: { app.mainPage = .settings })
            }
        }
        .frame(minWidth: 460, maxWidth: .infinity, minHeight: 520, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct PageHeader: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: Theme.s2) {
            Button(action: onBack) {
                HStack(spacing: 3) {
                    Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                    Text("Back").font(.system(size: 13))
                }
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text(title)
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            // Balances the back button so the title stays optically centred.
            Color.clear.frame(width: 52, height: 1)
        }
        .padding(.horizontal, Theme.s4)
        .padding(.vertical, Theme.s3)
    }
}
