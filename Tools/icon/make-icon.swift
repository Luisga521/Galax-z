// Draws Galax-z's app icon: a spiral galaxy on a dot matrix, the way an LED grid would show it, in the three
// versions iOS uses (light, dark, tinted). Writes the PNGs and Contents.json into the app icon set.
//
//   swift Tools/icon/make-icon.swift App/Assets.xcassets/AppIcon.appiconset

import CoreGraphics
import Foundation
import ImageIO

let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let size = 1024
let grid = 31                                   // dots per side
let pitch = Double(size) / Double(grid)

struct RGB { var r, g, b: Double }
func hex(_ v: UInt32) -> RGB { RGB(r: Double(v >> 16 & 0xFF) / 255, g: Double(v >> 8 & 0xFF) / 255, b: Double(v & 0xFF) / 255) }

struct Style {
    var name: String
    var centre: RGB, edge: RGB                  // background, a soft radial glow
    var dot: RGB, core: RGB                     // lit dots, the galaxy's core
    var offAlpha: Double                        // the unlit LEDs
}

let styles = [
    Style(name: "icon-dark", centre: hex(0x1A1A1E), edge: hex(0x0C0C0D), dot: hex(0xEDEBE6), core: hex(0xFFD23F),
          offAlpha: 0.10),
    Style(name: "icon-light", centre: hex(0xF6F4EF), edge: hex(0xE4E1DA), dot: hex(0x141416), core: hex(0xFF5A36),
          offAlpha: 0.08),
    Style(name: "icon-tinted", centre: hex(0x000000), edge: hex(0x000000), dot: hex(0xFFFFFF), core: hex(0xFFFFFF),
          offAlpha: 0.12),
]

func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
    let t = min(1, max(0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)
}

/// Brightness of the galaxy at a point: a bright core, two logarithmic arms, a faint disc; and how much is core.
func galaxy(_ x: Double, _ y: Double) -> (light: Double, core: Double) {
    let c = Double(size) / 2, radius = Double(size) * 0.39
    let u0 = (x - c) / radius, v0 = (y - c) / radius
    let tilt = -30.0 * .pi / 180
    let u = u0 * cos(tilt) - v0 * sin(tilt)
    let v = (u0 * sin(tilt) + v0 * cos(tilt)) / 0.9   // seen a little from the side
    let r = (u * u + v * v).squareRoot(), theta = atan2(v, u)
    let core = exp(-pow(r / 0.2, 2))
    var arms = 0.0
    for k in 0..<2 {
        let d = remainder(theta - log(r + 0.06) * 2.9 - Double(k) * .pi, 2 * .pi)
        arms = max(arms, exp(-pow(d / (0.5 + 0.35 * r), 2)))   // arms widen outward
    }
    let fade = 1 - smoothstep(0.6, 1.05, r)
    let disc = 0.22 * exp(-pow(r / 0.6, 2))
    return (min(1, core + arms * fade * (0.55 + 0.45 * (1 - r)) + disc), core)
}

/// A few far stars, the same every run.
func star(_ i: Int, _ j: Int) -> Bool {
    var h = UInt32(truncatingIfNeeded: i &* 73_856_093 ^ j &* 19_349_663)
    h ^= h >> 13; h = h &* 0x5BD1_E995; h ^= h >> 15
    return h % 100 < 4
}

func draw(_ s: Style) -> CGImage {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let g = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    let glow = CGGradient(colorsSpace: space, colors: [
        CGColor(srgbRed: s.centre.r, green: s.centre.g, blue: s.centre.b, alpha: 1),
        CGColor(srgbRed: s.edge.r, green: s.edge.g, blue: s.edge.b, alpha: 1),
    ] as CFArray, locations: [0, 1])!
    let mid = CGPoint(x: size / 2, y: size / 2)
    g.drawRadialGradient(glow, startCenter: mid, startRadius: 0, endCenter: mid, endRadius: CGFloat(size) * 0.72,
                         options: [.drawsAfterEndLocation])
    let maxRadius = pitch * 0.42
    for j in 0..<grid {
        for i in 0..<grid {
            let x = (Double(i) + 0.5) * pitch, y = (Double(j) + 0.5) * pitch
            let (light, core) = galaxy(x, y)
            var radius = maxRadius * 0.26, colour = s.dot, alpha = s.offAlpha
            if light > 0.12 {
                radius = maxRadius * (0.28 + 0.72 * light.squareRoot())
                alpha = 0.3 + 0.7 * light
                if core > 0.45 { colour = s.core; alpha = 1 }
            } else if star(i, j) {
                radius = maxRadius * 0.3
                alpha = 0.55
            }
            g.setFillColor(CGColor(srgbRed: colour.r, green: colour.g, blue: colour.b, alpha: alpha))
            g.fillEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
        }
    }
    return g.makeImage()!
}

try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
for s in styles {
    let url = outDir.appendingPathComponent("\(s.name).png")
    let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, draw(s), nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("could not write \(url.path)") }
    print("wrote \(url.lastPathComponent)")
}

let contents = """
{
  "images" : [
    { "filename" : "icon-light.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ],
      "filename" : "icon-dark.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "tinted" } ],
      "filename" : "icon-tinted.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}

"""
try contents.write(to: outDir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
try "{\n  \"info\" : { \"author\" : \"xcode\", \"version\" : 1 }\n}\n"
    .write(to: outDir.deletingLastPathComponent().appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
