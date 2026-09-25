// Genera Resources/AppIcon.icns: swift Scripts/make_icon.swift
import AppKit

let size: CGFloat = 1024
let orange = NSColor(red: 0.85, green: 0.47, blue: 0.34, alpha: 1)
let green = NSColor(red: 0.36, green: 0.84, blue: 0.52, alpha: 1)
let yellow = NSColor(red: 1.0, green: 0.78, blue: 0.3, alpha: 1)

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// Sfondo: squircle macOS (griglia 824pt con margine 100) e gradiente scuro.
let box = NSRect(x: 100, y: 100, width: 824, height: 824)
let squircle = NSBezierPath(roundedRect: box, xRadius: 185, yRadius: 185)
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
shadow.shadowBlurRadius = 24
shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.set()
NSColor.black.setFill()
squircle.fill()
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.saveGraphicsState()
squircle.addClip()
NSGradient(starting: NSColor(white: 0.22, alpha: 1), ending: NSColor(white: 0.07, alpha: 1))!
    .draw(in: box, angle: -90)

// Notch in alto, con le curve "inverse" come in NotchShape.
let nw: CGFloat = 400, nh: CGFloat = 96, t: CGFloat = 22, b: CGFloat = 44
let nx = box.midX - nw / 2, top = box.maxY, bottom = box.maxY - nh
let notch = NSBezierPath()
notch.move(to: NSPoint(x: nx, y: top))
notch.curve(to: NSPoint(x: nx + t, y: top - t), controlPoint1: NSPoint(x: nx + t, y: top), controlPoint2: NSPoint(x: nx + t, y: top))
notch.line(to: NSPoint(x: nx + t, y: bottom + b))
notch.curve(to: NSPoint(x: nx + t + b, y: bottom), controlPoint1: NSPoint(x: nx + t, y: bottom), controlPoint2: NSPoint(x: nx + t, y: bottom))
notch.line(to: NSPoint(x: nx + nw - t - b, y: bottom))
notch.curve(to: NSPoint(x: nx + nw - t, y: bottom + b), controlPoint1: NSPoint(x: nx + nw - t, y: bottom), controlPoint2: NSPoint(x: nx + nw - t, y: bottom))
notch.line(to: NSPoint(x: nx + nw - t, y: top - t))
notch.curve(to: NSPoint(x: nx + nw, y: top), controlPoint1: NSPoint(x: nx + nw - t, y: top), controlPoint2: NSPoint(x: nx + nw - t, y: top))
notch.close()
NSColor.black.setFill()
notch.fill()

// Anello di utilizzo (~72%) con gradiente verde → giallo → arancio.
let center = NSPoint(x: box.midX, y: box.midY - 50)
let radius: CGFloat = 250, lw: CGFloat = 56
ctx.setLineWidth(lw)
ctx.setLineCap(.round)
ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.1).cgColor)
ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
ctx.strokePath()

let progress: CGFloat = 0.72
let start = CGFloat.pi / 2, end = start - progress * .pi * 2
// CoreGraphics non ha gradienti conici: disegniamo l'arco a piccoli segmenti.
func mix(_ a: NSColor, _ b: NSColor, _ f: CGFloat) -> CGColor {
    NSColor(red: a.redComponent + (b.redComponent - a.redComponent) * f,
            green: a.greenComponent + (b.greenComponent - a.greenComponent) * f,
            blue: a.blueComponent + (b.blueComponent - a.blueComponent) * f, alpha: 1).cgColor
}
let steps = 240
ctx.setLineCap(.butt)
for i in 0..<steps {
    let f0 = CGFloat(i) / CGFloat(steps), f1 = CGFloat(i + 1) / CGFloat(steps)
    ctx.setStrokeColor(f0 < 0.5 ? mix(green, yellow, f0 * 2) : mix(yellow, orange, (f0 - 0.5) * 2))
    ctx.addArc(center: center, radius: radius, startAngle: start + (end - start) * f0,
               endAngle: start + (end - start) * min(1, f1 + 0.002), clockwise: true)
    ctx.strokePath()
}
// Estremità arrotondate.
for (angle, color) in [(start, green.cgColor), (end, orange.cgColor)] {
    ctx.setFillColor(color)
    let p = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    ctx.fillEllipse(in: CGRect(x: p.x - lw / 2, y: p.y - lw / 2, width: lw, height: lw))
}

// Sparkle arancione al centro.
let cfg = NSImage.SymbolConfiguration(pointSize: 250, weight: .bold)
    .applying(NSImage.SymbolConfiguration(paletteColors: [orange]))
if let sparkle = NSImage(systemSymbolName: "sparkle", accessibilityDescription: nil)?.withSymbolConfiguration(cfg) {
    let s = sparkle.size
    sparkle.draw(in: NSRect(x: center.x - s.width / 2, y: center.y - s.height / 2, width: s.width, height: s.height))
}
NSGraphicsContext.restoreGraphicsState()
NSGraphicsContext.current = nil

// Iconset → icns
let fm = FileManager.default
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconset)
try! fm.createDirectory(at: iconset, withIntermediateDirectories: true)
let master = rep
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = base * scale
        let out = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)
        NSGraphicsContext.current!.imageInterpolation = .high
        master.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
        NSGraphicsContext.current = nil
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try! out.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(name))
    }
}
try! master.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "Resources/AppIcon.png"))
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try! p.run(); p.waitUntilExit()
print(p.terminationStatus == 0 ? "Creata Resources/AppIcon.icns" : "iconutil fallito")
