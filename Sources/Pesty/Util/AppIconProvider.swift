import AppKit

@MainActor
enum AppIconProvider {
    private static var cache: [String: NSImage] = [:]
    private static var sizedCache: [String: NSImage] = [:]
    private static let sizedCacheLimit = 100

    static func icon(forBundleID bundleID: String?) -> NSImage {
        guard let bundleID else { return generic }
        if let cached = cache[bundleID] { return cached }
        var image = generic
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            image = NSWorkspace.shared.icon(forFile: url.path)
        }
        cache[bundleID] = image
        return image
    }

    /// Renders the icon at an exact pixel count so the card does not ask
    /// SwiftUI to resample it again. A 48 pt icon on a 2x display becomes a
    /// 96 px bitmap, which maps one-to-one onto the screen grid.
    static func icon(forBundleID bundleID: String?, pointSize: CGFloat, scale: CGFloat) -> NSImage {
        let pixels = max(1, Int((pointSize * scale).rounded()))
        let key = "\(bundleID ?? "-")|\(pixels)"
        if let cached = sizedCache[key] { return cached }
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return icon(forBundleID: bundleID) }

        rep.size = NSSize(width: pointSize, height: pointSize)
        NSGraphicsContext.saveGraphicsState()
        if let context = NSGraphicsContext(bitmapImageRep: rep) {
            NSGraphicsContext.current = context
            context.imageInterpolation = .high
            icon(forBundleID: bundleID).draw(
                in: NSRect(x: 0, y: 0, width: pointSize, height: pointSize),
                from: .zero, operation: .sourceOver, fraction: 1)
            context.flushGraphics()
        }
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: NSSize(width: pointSize, height: pointSize))
        image.addRepresentation(rep)
        if sizedCache.count >= sizedCacheLimit { sizedCache.removeAll() }
        sizedCache[key] = image
        return image
    }

    static let generic: NSImage =
        NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil)
        ?? NSImage()
}
