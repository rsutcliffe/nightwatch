// Builds a classic .icns from the Icon Composer artwork, for builds without Xcode's actool (Command Line Tools only).
// The full-bleed art is drawn into Apple's rounded-square grid (824 pt tile in a 1024 canvas), which macOS 14 and 15 expect.
// Usage: swift scripts/make-icns.swift <art.png> <out.icns>
import AppKit

let args = CommandLine.arguments
guard args.count == 3, let art = NSImage(contentsOfFile: args[1]) else { print("usage: make-icns.swift art.png out.icns"); exit(1) }
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Nightwatch.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func png(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px) / 1024, tile = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    NSBezierPath(roundedRect: tile, xRadius: 185 * s, yRadius: 185 * s).addClip()
    art.draw(in: tile, from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}
for pt in [16, 32, 128, 256, 512] {
    try png(pt).write(to: iconset.appendingPathComponent("icon_\(pt)x\(pt).png"))
    try png(pt * 2).write(to: iconset.appendingPathComponent("icon_\(pt)x\(pt)@2x.png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", args[2]]
try p.run(); p.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
exit(p.terminationStatus)
