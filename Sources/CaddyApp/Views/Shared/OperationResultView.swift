import SwiftUI

struct OperationResultView: View {
    let title: String?
    let message: String
    let detail: String?
    let isSuccess: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title {
                Text(title)
                    .font(.headline)
            }
            Text(message)
                .foregroundStyle(isSuccess ? .green : .red)
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
