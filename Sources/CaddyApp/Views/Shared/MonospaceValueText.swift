import SwiftUI

struct MonospaceValueText: View {
    let value: String
    var body: some View {
        Text(value)
            .font(.system(.body, design: .monospaced))
    }
}
