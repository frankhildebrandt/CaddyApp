import SwiftUI

struct DocumentationWindowView: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Label("CaddyApp Dokumentation", systemImage: "book.closed")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))

                Spacer()

                Text(DocumentationAccess.siteURL.absoluteString)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.thinMaterial)

            DocumentationWebView(url: DocumentationAccess.siteURL)
        }
    }
}
