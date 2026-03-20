import SwiftUI

enum AppChrome {
    static let canvasTop = Color(red: 0.95, green: 0.97, blue: 1.0)
    static let canvasBottom = Color(red: 0.92, green: 0.95, blue: 0.99)
    static let sidebarFill = Color.white.opacity(0.72)
    static let panelFill = Color.white.opacity(0.78)
    static let tileFill = Color.white.opacity(0.72)
    static let shadow = Color.black.opacity(0.08)
    static let primaryText = Color(red: 0.12, green: 0.14, blue: 0.18)
    static let secondaryText = Color(red: 0.42, green: 0.45, blue: 0.52)
    static let accent = Color(red: 0.09, green: 0.41, blue: 0.93)
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
                            .strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
                    )
                    .shadow(color: AppChrome.shadow, radius: 20, x: 0, y: 12)
            )
    }
}

extension View {
    func appGlassCard(cornerRadius: CGFloat = 24, fill: Color = AppChrome.panelFill) -> some View {
        modifier(AppGlassCardModifier(cornerRadius: cornerRadius, fill: fill))
    }
}
