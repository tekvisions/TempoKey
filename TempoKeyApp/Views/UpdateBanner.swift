import SwiftUI

/// Slim, dismissible "an update is available" bar shown at the top of the window.
struct UpdateBanner: View {
    let update: AppUpdate
    let onDismiss: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill").foregroundStyle(Theme.accent)
            Text("TempoKey \(update.version) is available")
                .font(.callout)
            Spacer()
            Button("Download") { openURL(update.url) }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
            Button { onDismiss() } label: { Image(systemName: "xmark") }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Dismiss")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Theme.accent.opacity(0.12))
        .overlay(alignment: .bottom) { Divider() }
    }
}
