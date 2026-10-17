// Renders the Notify Anywhere app icon (1024×1024 PNG) in Liftoff Media brand colors.
// Usage: swift Tools/MakeIcon.swift <output.png>
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

// Apple icon grid: 824pt body centred on a 1024 canvas, continuous-corner radius ≈ 185.
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let squircle = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

// Drop shadow
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: rgb(0x000000, 0.45))
ctx.addPath(squircle); ctx.setFillColor(rgb(0x0B0B0F)); ctx.fillPath()
ctx.restoreGState()

// Background gradient
ctx.saveGState()
ctx.addPath(squircle); ctx.clip()
let bg = CGGradient(colorsSpace: space, colors: [rgb(0x3B1286), rgb(0x1A0B3D), rgb(0x0B0B0F)] as CFArray,
                    locations: [0, 0.55, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 200, y: 924), end: CGPoint(x: 820, y: 100), options: [])
// Soft glows
let glowPink = CGGradient(colorsSpace: space, colors: [rgb(0xEC4899, 0.55), rgb(0xEC4899, 0)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(glowPink, startCenter: CGPoint(x: 300, y: 330), startRadius: 0,
                       endCenter: CGPoint(x: 300, y: 330), endRadius: 380, options: [])
let glowViolet = CGGradient(colorsSpace: space, colors: [rgb(0x7C3AED, 0.6), rgb(0x7C3AED, 0)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(glowViolet, startCenter: CGPoint(x: 760, y: 760), startRadius: 0,
                       endCenter: CGPoint(x: 760, y: 760), endRadius: 360, options: [])
// Top highlight
let shine = CGGradient(colorsSpace: space, colors: [rgb(0xFFFFFF, 0.14), rgb(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(shine, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 640), options: [])
ctx.restoreGState()

func card(_ rect: CGRect, alpha: CGFloat, solid: Bool) {
    let path = CGPath(roundedRect: rect, cornerWidth: rect.height * 0.28, cornerHeight: rect.height * 0.28, transform: nil)
    ctx.saveGState()
    if solid { ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 40, color: rgb(0x000000, 0.5)) }
    ctx.addPath(path)
    ctx.setFillColor(rgb(0xFFFFFF, alpha))
    ctx.fillPath()
    ctx.restoreGState()
    if !solid {
        ctx.addPath(path)
        ctx.setStrokeColor(rgb(0xFFFFFF, 0.35))
        ctx.setLineWidth(5)
        ctx.setLineDash(phase: 0, lengths: [18, 14])
        ctx.strokePath()
        ctx.setLineDash(phase: 0, lengths: [])
        return
    }
    // App badge with brand gradient
    let d = rect.height * 0.58
    let badge = CGRect(x: rect.minX + rect.height * 0.21, y: rect.midY - d / 2, width: d, height: d)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: badge, cornerWidth: d * 0.27, cornerHeight: d * 0.27, transform: nil))
    ctx.clip()
    let g = CGGradient(colorsSpace: space, colors: [rgb(0xEC4899), rgb(0x7C3AED)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: badge.minX, y: badge.maxY), end: CGPoint(x: badge.maxX, y: badge.minY), options: [])
    ctx.restoreGState()
    // Text lines
    let x = badge.maxX + rect.height * 0.18
    ctx.setFillColor(rgb(0x1A1A24, 0.9))
    ctx.addPath(CGPath(roundedRect: CGRect(x: x, y: rect.midY + 8, width: rect.maxX - x - 50, height: 26),
                       cornerWidth: 13, cornerHeight: 13, transform: nil)); ctx.fillPath()
    ctx.setFillColor(rgb(0x1A1A24, 0.35))
    ctx.addPath(CGPath(roundedRect: CGRect(x: x, y: rect.midY - 38, width: (rect.maxX - x - 50) * 0.7, height: 22),
                       cornerWidth: 11, cornerHeight: 11, transform: nil)); ctx.fillPath()
}

// Ghost banner where macOS normally puts it (top right)
let ghost = CGRect(x: 520, y: 742, width: 330, height: 108)
card(ghost, alpha: 0.06, solid: false)

// Trajectory arc from the ghost to the new spot
let arc = CGMutablePath()
arc.move(to: CGPoint(x: 600, y: 726))
arc.addCurve(to: CGPoint(x: 330, y: 470), control1: CGPoint(x: 560, y: 560), control2: CGPoint(x: 450, y: 480))
ctx.saveGState()
ctx.addPath(arc)
ctx.setStrokeColor(rgb(0xC4B5FD, 0.95))
ctx.setLineWidth(14)
ctx.setLineCap(.round)
ctx.setLineDash(phase: 0, lengths: [2, 30])
ctx.strokePath()
ctx.restoreGState()
// Arrow head
let head = CGMutablePath()
head.move(to: CGPoint(x: 300, y: 462))
head.addLine(to: CGPoint(x: 362, y: 500))
head.addLine(to: CGPoint(x: 352, y: 436))
head.closeSubpath()
ctx.addPath(head); ctx.setFillColor(rgb(0xC4B5FD)); ctx.fillPath()

// The moved notification (bottom left), solid white
card(CGRect(x: 168, y: 250, width: 520, height: 160), alpha: 1, solid: true)

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
