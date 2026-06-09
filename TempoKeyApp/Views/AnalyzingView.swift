import SwiftUI

struct AnalyzingView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        VStack(spacing: 16) {
            ProgressView(value: state.progress) { Text("Analyzing…") }
                .progressViewStyle(.linear)
                .frame(width: 280)
            Text("\(Int(state.progress * 100))%").foregroundStyle(.secondary).monospacedDigit()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
