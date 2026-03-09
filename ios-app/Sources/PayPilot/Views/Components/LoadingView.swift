#if canImport(SwiftUI)
import SwiftUI

public struct LoadingView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.4)
            Text("Loading…")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

#endif // canImport(SwiftUI)
