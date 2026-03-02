import SwiftUI

struct StatusMessageView: View {
    let message: String
    let isSuccess: Bool
    var font: Font = .caption

    var body: some View {
        Text(message)
            .font(font)
            .foregroundStyle(isSuccess ? .green : .red)
    }
}
