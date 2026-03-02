import AppKit
import SwiftUI

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
        return rendered
    }()
}
