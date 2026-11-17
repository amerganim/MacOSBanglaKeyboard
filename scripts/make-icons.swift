// Renders the menu-bar icon (MenuIcon.tiff, 1x+2x) and the app icon
// (AppIcon.icns) from the Bangla letter "অ". Run: swift scripts/make-icons.swift <outdir>
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("bk-icons-\(getpid())")
try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

func png(_ size: Int, _ draw: (CGRect) -> Void) -> Data {
  let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                             colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  draw(CGRect(x: 0, y: 0, width: size, height: size))
  NSGraphicsContext.restoreGraphicsState()
  return rep.representation(using: .png, properties: [:])!
}

func letter(_ r: CGRect, scale: CGFloat, color: NSColor) {
  let font = NSFont(name: "Bangla Sangam MN", size: r.height * scale)
    ?? NSFont(name: "Kohinoor Bangla", size: r.height * scale)
    ?? NSFont.systemFont(ofSize: r.height * scale)
  // Center the glyph's actual ink bounds (font metrics put Bangla glyphs high).
  var ch: [UniChar] = Array("অ".utf16)
  var g = [CGGlyph](repeating: 0, count: ch.count)
  CTFontGetGlyphsForCharacters(font, &ch, &g, ch.count)
  let b = CTFontGetBoundingRectsForGlyphs(font, .horizontal, &g, nil, 1)
  let ctx = NSGraphicsContext.current!.cgContext
  ctx.setFillColor(color.cgColor)
  let path = CTFontCreatePathForGlyph(font, g[0], nil)!
  ctx.saveGState()
  ctx.translateBy(x: r.midX - b.midX, y: r.midY - b.midY)
  ctx.addPath(path); ctx.fillPath()
  ctx.restoreGState()
}

// Menu icon: black glyph on transparent (template-style), as large as fits.
func menu(_ r: CGRect) {
  letter(r, scale: 0.95, color: .black)
}

// App icon: white glyph on green/red Bangladesh-inspired tile.
func app(_ r: CGRect) {
  let inset = r.insetBy(dx: r.width * 0.1, dy: r.width * 0.1)
  let tile = NSBezierPath(roundedRect: inset, xRadius: r.width * 0.2, yRadius: r.width * 0.2)
  NSColor(red: 0, green: 0.42, blue: 0.31, alpha: 1).setFill(); tile.fill()
  let c = r.width * 0.2
  NSColor(red: 0.96, green: 0.16, blue: 0.25, alpha: 1).setFill()
  NSBezierPath(ovalIn: CGRect(x: inset.midX - c * 1.25, y: inset.midY - c * 1.25, width: 2.5 * c, height: 2.5 * c)).fill()
  letter(inset, scale: 0.55, color: .white)
}

let m1 = tmp.appendingPathComponent("m1.png"), m2 = tmp.appendingPathComponent("m2.png")
try png(16, menu).write(to: m1); try png(32, menu).write(to: m2)

let iconset = tmp.appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for s in [16, 32, 128, 256, 512] {
  try png(s, app).write(to: iconset.appendingPathComponent("icon_\(s)x\(s).png"))
  try png(s * 2, app).write(to: iconset.appendingPathComponent("icon_\(s)x\(s)@2x.png"))
}

func run(_ args: [String]) {
  let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/env"); p.arguments = args
  try! p.run(); p.waitUntilExit()
  if p.terminationStatus != 0 { fatalError("failed: \(args)") }
}
// 1x+2x TIFF: convert each PNG to TIFF, then combine.
run(["sips", "-s", "format", "tiff", m1.path, "--out", tmp.appendingPathComponent("m1.tiff").path])
run(["sips", "-s", "format", "tiff", m2.path, "--out", tmp.appendingPathComponent("m2.tiff").path])
run(["tiffutil", "-cathidpicheck", tmp.appendingPathComponent("m1.tiff").path,
     tmp.appendingPathComponent("m2.tiff").path, "-out", "\(out)/MenuIcon.tiff"])
run(["iconutil", "-c", "icns", iconset.path, "-o", "\(out)/AppIcon.icns"])
try? FileManager.default.removeItem(at: tmp)
print("wrote \(out)/MenuIcon.tiff and \(out)/AppIcon.icns")
