import SwiftUI

enum AppChrome {
    static let canvasTop = Color(red: 0.97, green: 0.98, blue: 1.0)
    static let canvasBottom = Color(red: 0.94, green: 0.96, blue: 0.99)
    static let contentCanvas = Color(red: 0.94, green: 0.96, blue: 0.99)
    static let sidebarFill = Color.white.opacity(0.86)
    static let panelFill = Color.white.opacity(0.58)
    static let tileFill = Color(red: 0.95, green: 0.96, blue: 0.98)
    static let tileSoftFill = Color.white.opacity(0.92)
    static let shadow = Color.black.opacity(0.05)
    static let primaryText = Color(red: 0.16, green: 0.18, blue: 0.22)
    static let secondaryText = Color(red: 0.46, green: 0.49, blue: 0.56)
    static let accent = Color(red: 0.09, green: 0.41, blue: 0.93)
    static let selectionFill = Color.black.opacity(0.07)
}

struct AppGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let fill: Color

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.72), lineWidth: 1)
                    )
                    .shadow(color: AppChrome.shadow, radius: 14, x: 0, y: 8)
            )
    }
}

extension View {
    func appGlassCard(cornerRadius: CGFloat = 24, fill: Color = AppChrome.panelFill) -> some View {
        modifier(AppGlassCardModifier(cornerRadius: cornerRadius, fill: fill))
    }
}
