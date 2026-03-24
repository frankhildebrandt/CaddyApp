import SwiftUI

enum AppChrome {
    static let canvasTop = Color(red: 0.95, green: 0.97, blue: 0.995)
    static let canvasBottom = Color(red: 0.88, green: 0.93, blue: 0.985)
    static let contentCanvas = Color(red: 0.93, green: 0.95, blue: 0.985)
    static let sidebarFill = Color.white.opacity(0.56)
    static let panelFill = Color.white.opacity(0.38)
    static let tileFill = Color.white.opacity(0.36)
    static let tileSoftFill = Color.white.opacity(0.28)
    static let border = Color.white.opacity(0.55)
    static let strongBorder = Color.white.opacity(0.82)
    static let shadow = Color.black.opacity(0.09)
    static let primaryText = Color(red: 0.12, green: 0.16, blue: 0.24)
    static let secondaryText = Color(red: 0.34, green: 0.41, blue: 0.53)
    static let accent = Color(red: 0.06, green: 0.39, blue: 0.86)
    static let accentSoft = Color(red: 0.36, green: 0.66, blue: 0.95)
    static let mintGlow = Color(red: 0.50, green: 0.87, blue: 0.84)
    static let selectionFill = Color.white.opacity(0.34)
}

struct AppAmbientBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppChrome.canvasTop, AppChrome.canvasBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(AppChrome.accentSoft.opacity(0.22))
                .frame(width: 520, height: 520)
                .blur(radius: 22)
                .offset(x: -320, y: -220)

            Circle()
                .fill(AppChrome.mintGlow.opacity(0.20))
                .frame(width: 440, height: 440)
                .blur(radius: 30)
                .offset(x: 260, y: -160)

            Circle()
                .fill(AppChrome.accent.opacity(0.10))
                .frame(width: 660, height: 660)
                .blur(radius: 44)
                .offset(x: 200, y: 280)

            Rectangle()
                .fill(.white.opacity(0.08))
                .mask(
                    LinearGradient(
                        colors: [.clear, .white, .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 24)
        }
    }
}

struct AppGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let fill: Color
    let prominent: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if #available(macOS 26.0, *) {
            content
                .glassEffect(
                    .regular.tint(prominent ? fill.opacity(0.42) : fill.opacity(0.30)),
                    in: shape
                )
                .overlay(
                    shape.strokeBorder(AppChrome.border, lineWidth: 1)
                )
                .shadow(color: AppChrome.shadow, radius: 18, x: 0, y: 14)
        } else {
            content
                .background(
                    shape
                        .fill(fill)
                        .overlay(
                            shape
                                .strokeBorder(AppChrome.strongBorder, lineWidth: 1)
                        )
                        .shadow(color: AppChrome.shadow, radius: 16, x: 0, y: 10)
                )
        }
    }
}

extension View {
    func appGlassCard(cornerRadius: CGFloat = 24, fill: Color = AppChrome.panelFill, prominent: Bool = false) -> some View {
        modifier(AppGlassCardModifier(cornerRadius: cornerRadius, fill: fill, prominent: prominent))
    }
}
