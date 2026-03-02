import SwiftUI

struct InlineActivitySkeleton: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color.secondary.opacity(0.2))
            .frame(width: 64, height: 14)
            .redacted(reason: .placeholder)
            .accessibilityLabel("Lädt")
    }
}
