// galaxz-frames: render a boot animation from the library (OPZFirmware/Animations.swift) for the OP-Z.
//
//   swift run --package-path Packages/GalaxzKit galaxz-frames galaxy Firmware/galaxy/frames.bin [sheet.svg [first frame]]
//   swift run --package-path Packages/GalaxzKit galaxz-frames list
//
// frames.bin is what the galaxy player plays (64 frames x 53 LEDs x R G B W); Firmware/tools/asm.py then puts it in
// patches/galaxy-boot.json. The sheet is every 6th frame as an SVG, to look at. The layout is Firmware/galaxy/layout.json.

import Foundation
import OPZFirmware

let args = CommandLine.arguments.dropFirst()
let root = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "../../../..").standardized
guard let id = args.first else { print("usage: galaxz-frames <animation|list> <frames.bin> [sheet.svg]"); exit(2) }
if id == "list" {
    for a in LEDAnimation.library { print("\(a.id.padding(toLength: 10, withPad: " ", startingAt: 0)) \(a.blurb)") }
    exit(0)
}
guard let anim = LEDAnimation.library.first(where: { $0.id == id }), args.count >= 2 else {
    print("unknown animation \(id); try: list"); exit(2)
}
let layout = try LEDLayout.load(root.appending(path: "Firmware/galaxy/layout.json"))
let bytes = anim.bytes(layout)
try Data(bytes).write(to: URL(filePath: Array(args)[1]))
print("\(anim.name): \(LEDAnimation.frameCount) frames, \(bytes.count) bytes -> \(Array(args)[1])")

if args.count >= 3 {
    let frames = anim.frames(layout)
    let pos = layout.points.mapValues { (40 + $0.x * 880, 40 + $0.aspectY * 880) }
    let height = 80 + (layout.points.values.map(\.aspectY).max() ?? 0) * 880
    let from = args.count >= 4 ? Int(Array(args)[3]) ?? 0 : 0           // optional: first frame of the sheet
    let step = args.count >= 5 ? Int(Array(args)[4]) ?? 6 : (from > 0 ? 3 : 6)   // optional: frames between rows
    let picks = Array(stride(from: from, to: frames.count, by: step)) + [frames.count - 1]
    var svg = ["<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"960\" height=\"\(Int(height) * picks.count)\">",
               "<rect width=\"100%\" height=\"100%\" fill=\"#2a2a2c\"/>"]
    for (n, f) in picks.enumerated() {
        let oy = Double(n) * height
        svg.append("<text x=\"8\" y=\"\(Int(oy) + 16)\" fill=\"#888\" font-family=\"monospace\" font-size=\"12\">\(anim.name) frame \(f)</text>")
        for (i, p) in pos {
            let c = frames[f][i]
            let rgb = (0..<3).map { Int(255 * min(1, c[$0] + 0.8 * c[3])) }   // as it looks: white adds to all
            svg.append("<circle cx=\"\(Int(p.0))\" cy=\"\(Int(oy + p.1))\" r=\"13\" fill=\"rgb(\(rgb[0]),\(rgb[1]),\(rgb[2]))\"/>")
        }
    }
    svg.append("</svg>")
    try svg.joined(separator: "\n").write(to: URL(filePath: Array(args)[2]), atomically: true, encoding: .utf8)
}
