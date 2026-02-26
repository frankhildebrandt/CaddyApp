import SwiftUI
import AppKit

struct AppBrandIcon: View {
    var size: CGFloat = 40

    var body: some View {
        let radius = size * 0.24

        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.06, green: 0.65, blue: 0.91),
                            Color(red: 0.15, green: 0.39, blue: 0.92),
                            Color(red: 0.06, green: 0.46, blue: 0.43)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.30), .clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )

            Circle()
                .trim(from: 0.14, to: 0.86)
                .stroke(.white, style: StrokeStyle(lineWidth: size * 0.13, lineCap: .round))
                .frame(width: size * 0.55, height: size * 0.55)
                .shadow(color: .black.opacity(0.12), radius: 1.5, y: 1)

            Capsule()
                .fill(.white.opacity(0.95))
                .frame(width: size * 0.22, height: size * 0.07)
                .offset(x: size * 0.09)

            Circle()
                .fill(.white.opacity(0.95))
                .frame(width: size * 0.07, height: size * 0.07)
                .offset(x: -size * 0.06)

            Circle()
                .fill(Color(red: 0.98, green: 0.45, blue: 0.10))
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.13, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: size * 0.18, height: size * 0.18)
                .offset(x: size * 0.22)
                .shadow(color: .black.opacity(0.16), radius: 1.5, y: 1)

            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
        .frame(width: size, height: size)
    }
}

struct MenuBarSystrayIcon: View {
    var body: some View {
        Group {
            if let image = Self.menuBarColorImage {
                Image(nsImage: image)
            } else if let image = Self.menuBarTemplateImage {
                Image(nsImage: image)
            } else {
                fallbackVectorIcon
            }
        }
        .frame(width: 18, height: 18)
        .accessibilityLabel("CaddyApp")
    }

    private var fallbackVectorIcon: some View {
        ZStack {
            Circle()
                .trim(from: 0.14, to: 0.86)
                .stroke(.primary, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                .frame(width: 13.5, height: 13.5)

            Capsule()
                .fill(.primary)
                .frame(width: 5.5, height: 1.9)
                .offset(x: 2.2)

            Circle()
                .fill(.primary)
                .frame(width: 2.2, height: 2.2)
                .offset(x: -1.7)

            Circle()
                .fill(.primary)
                .frame(width: 3.2, height: 3.2)
                .offset(x: 5.2)
        }
        .compositingGroup()
    }

    private static let menuBarTemplateImage: NSImage? = {
        guard let url = Bundle.module.url(forResource: "SystrayIconTemplate", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }

        image.isTemplate = true
        return image
    }()

    private static let menuBarColorImage: NSImage? = {
        guard let url = Bundle.module.url(forResource: "AppIcon-preview", withExtension: "png"),
              let sourceImage = NSImage(contentsOf: url) else {
            return nil
        }

        let canvasSize = NSSize(width: 18, height: 18)
        let drawSize = NSSize(width: 14, height: 14)
        let drawOrigin = NSPoint(
            x: (canvasSize.width - drawSize.width) / 2,
            y: (canvasSize.height - drawSize.height) / 2
        )

        let rendered = NSImage(size: canvasSize)
        rendered.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        sourceImage.draw(
            in: NSRect(origin: drawOrigin, size: drawSize),
            from: NSRect(origin: .zero, size: sourceImage.size),
            operation: .sourceOver,
            fraction: 1
        )
        rendered.unlockFocus()

        rendered.isTemplate = false
        rendered.size = canvasSize
        return rendered
    }()
}
