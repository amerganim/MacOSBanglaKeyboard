// Renders the app icon (AppIcon.icns), the menu-bar icon (MenuIcon.tiff,
// 1x+2x) and the website icon (site/icon.png) from resources/icon-source.png
// — the same 512x512 icon used by the Android and Windows keyboards.
//   swift scripts/make-icons.swift   (run from the repo root)
import AppKit

let src = NSImage(contentsOfFile: "resources/icon-source.png")!
let srcRep = NSBitmapImageRep(data: src.tiffRepresentation!)!
let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("bk-icons-\(getpid())")
try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

func png(_ size: Int, _ draw: (CGRect) -> Void) -> Data {
  let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                             colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  NSGraphicsContext.current!.imageInterpolation = .high
  draw(CGRect(x: 0, y: 0, width: size, height: size))
  NSGraphicsContext.restoreGraphicsState()
  return rep.representation(using: .png, properties: [:])!
}

// macOS app icon: the artwork as a rounded square with the standard margin.
func app(_ r: CGRect) {
  let inset = r.insetBy(dx: r.width * 0.098, dy: r.width * 0.098)
  NSBezierPath(roundedRect: inset, xRadius: inset.width * 0.225, yRadius: inset.width * 0.225).addClip()
  src.draw(in: inset)
}

// Menu-bar icon: just the keyboard glyph (the white parts), in black, so macOS
// can tint it for light/dark menu bars. Crops to the glyph's bounding box.
let glyphMask: NSImage = {
  let w = srcRep.pixelsWide, h = srcRep.pixelsHigh
  var minX = w, minY = h, maxX = 0, maxY = 0
  let out = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8,
                             samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                             colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  for y in 0..<h { for x in 0..<w {
    let c = srcRep.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
    // White keys vs. purple background: use the green channel as "whiteness".
    let a = max(0, min(1, (c.greenComponent - 0.36) / (1 - 0.36)))
    out.setColor(NSColor(deviceRed: 0, green: 0, blue: 0, alpha: a), atX: x, y: y)
    if a > 0.5 { minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y) }
  }}
  let img = NSImage(size: NSSize(width: w, height: h)); img.addRepresentation(out)
  let crop = NSImage(size: NSSize(width: maxX - minX + 1, height: maxY - minY + 1))
  crop.lockFocus()
  // NSBitmapImageRep y=0 is the top row; NSImage drawing is bottom-up.
  img.draw(at: .zero, from: NSRect(x: minX, y: h - 1 - maxY, width: maxX - minX + 1, height: maxY - minY + 1),
           operation: .copy, fraction: 1)
  crop.unlockFocus()
  return crop
}()

func menu(_ r: CGRect) {
  let s = glyphMask.size
  let scale = min(r.width / s.width, r.height / s.height) * 0.98
  let w = s.width * scale, h = s.height * scale
  glyphMask.draw(in: CGRect(x: r.midX - w / 2, y: r.midY - h / 2, width: w, height: h))
}

let m1 = tmp.appendingPathComponent("m1.png"), m2 = tmp.appendingPathComponent("m2.png")
try png(16, menu).write(to: m1); try png(32, menu).write(to: m2)

let iconset = tmp.appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for s in [16, 32, 128, 256, 512] {
  try png(s, app).write(to: iconset.appendingPathComponent("icon_\(s)x\(s).png"))
  try png(s * 2, app).write(to: iconset.appendingPathComponent("icon_\(s)x\(s)@2x.png"))
}
// Website favicon / header: rounded like the app icon.
try png(256, app).write(to: URL(fileURLWithPath: "site/icon.png"))

func run(_ args: [String]) {
  let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/env"); p.arguments = args
  p.standardOutput = FileHandle.nullDevice
  try! p.run(); p.waitUntilExit()
  if p.terminationStatus != 0 { fatalError("failed: \(args)") }
}
run(["sips", "-s", "format", "tiff", m1.path, "--out", tmp.appendingPathComponent("m1.tiff").path])
run(["sips", "-s", "format", "tiff", m2.path, "--out", tmp.appendingPathComponent("m2.tiff").path])
run(["tiffutil", "-cathidpicheck", tmp.appendingPathComponent("m1.tiff").path,
     tmp.appendingPathComponent("m2.tiff").path, "-out", "resources/MenuIcon.tiff"])
run(["iconutil", "-c", "icns", iconset.path, "-o", "resources/AppIcon.icns"])
try? FileManager.default.removeItem(at: tmp)
print("wrote resources/AppIcon.icns, resources/MenuIcon.tiff, site/icon.png")
