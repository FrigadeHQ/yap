import AppKit

/// The menu-bar mic, drawn at runtime so it stays crisp at any scale factor and
/// matches the Dock icon's silhouette without bundling extra image assets.
///
/// Rendered as a template image, so macOS handles light/dark menu bars and the
/// highlighted state automatically.
enum MenuBarIcon {
    static func image(recording: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)

        let image = NSImage(size: size, flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return true }

            // Geometry mirrors the app icon: rounded-rect head, stem, base.
            let head = CGRect(x: 5.5, y: 6.0, width: 7.0, height: 10.5)
            let headPath = CGPath(
                roundedRect: head, cornerWidth: 3.5, cornerHeight: 3.5, transform: nil
            )
            let stem = CGRect(x: 8.6, y: 3.0, width: 0.8, height: 3.2)
            let base = CGRect(x: 6.0, y: 2.0, width: 6.0, height: 1.1)
            let basePath = CGPath(
                roundedRect: base, cornerWidth: 0.55, cornerHeight: 0.55, transform: nil
            )

            context.setFillColor(NSColor.black.cgColor)
            context.setStrokeColor(NSColor.black.cgColor)

            if recording {
                // Solid head reads as "live" at a glance.
                context.addPath(headPath)
                context.fillPath()
            } else {
                context.addPath(headPath)
                context.setLineWidth(1.3)
                context.strokePath()
            }

            context.addPath(CGPath(rect: stem, transform: nil))
            context.fillPath()
            context.addPath(basePath)
            context.fillPath()

            return true
        }

        image.isTemplate = true
        return image
    }
}
