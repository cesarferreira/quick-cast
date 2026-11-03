import AppKit

let destination = CommandLine.arguments[1]
let set = URL(fileURLWithPath: destination).appendingPathComponent("QuickCast.iconset")
try FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)

func icon(_ pixels: Int) -> Data {
    let image = NSImage(size: NSSize(width: pixels, height: pixels))
    image.lockFocus()
    let factor = CGFloat(pixels) / 1024
    NSGraphicsContext.current!.cgContext.scaleBy(x: factor, y: factor)
    let base = NSBezierPath(roundedRect: NSRect(x: 68, y: 68, width: 888, height: 888), xRadius: 202, yRadius: 202)
    NSGradient(starting: NSColor(calibratedRed: 0.16, green: 0.20, blue: 0.21, alpha: 1), ending: NSColor(calibratedRed: 0.045, green: 0.065, blue: 0.075, alpha: 1))!.draw(in: base, angle: -60)
    NSColor.white.withAlphaComponent(0.13).setStroke()
    base.lineWidth = 3
    base.stroke()
    let mint = NSColor(calibratedRed: 0.57, green: 0.97, blue: 0.77, alpha: 1)
    let keys: [(NSRect, String, Bool)] = [
        (NSRect(x: 194, y: 355, width: 286, height: 314), "⌘", false),
        (NSRect(x: 514, y: 355, width: 316, height: 314), "K", true)
    ]
    for (rect, text, primary) in keys {
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
        shadow.shadowBlurRadius = 30
        shadow.shadowOffset = NSSize(width: 0, height: -16)
        shadow.set()
        let shape = NSBezierPath(roundedRect: rect, xRadius: 57, yRadius: 57)
        (primary ? mint : NSColor(calibratedWhite: 0.22, alpha: 1)).setFill()
        shape.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSColor.white.withAlphaComponent(primary ? 0.4 : 0.18).setStroke()
        shape.lineWidth = 3
        shape.stroke()
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 184, weight: .medium), .foregroundColor: primary ? NSColor(calibratedWhite: 0.08, alpha: 1) : NSColor.white]
        let label = NSAttributedString(string: text, attributes: attrs)
        let size = label.size()
        label.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2 + 8))
    }
    let dot = NSBezierPath(ovalIn: NSRect(x: 461, y: 238, width: 18, height: 18))
    mint.setFill()
    dot.fill()
    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 22, weight: .semibold), .foregroundColor: NSColor.white.withAlphaComponent(0.5), .kern: 7]
    NSAttributedString(string: "LIVE", attributes: attrs).draw(at: NSPoint(x: 501, y: 230))
    image.unlockFocus()
    let representation = NSBitmapImageRep(data: image.tiffRepresentation!)!
    return representation.representation(using: .png, properties: [:])!
}
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 2 ? "@2x" : ""
        try icon(points * scale).write(to: set.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
    }
}
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", set.path, "-o", URL(fileURLWithPath: destination).appendingPathComponent("QuickCast.icns").path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else { exit(process.terminationStatus) }
try FileManager.default.removeItem(at: set)
