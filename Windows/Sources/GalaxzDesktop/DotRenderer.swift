import Dispatch
import Foundation

/// The matrix of lights drawn by the CPU: `App/DotShaders.swift` (Metal) and `Android/…/DotView.kt` (GLSL) in plain
/// Swift, for a window that only takes pixels (GDI on Windows). The same four passes: this frame's lights or what is
/// left of the last one's, a blur across, a blur down, then every dot a round light on dark glass with the blurred light
/// around it. Pixels are 32-bit B, G, R, X, top row first: what a top-down DIB section wants.
public final class DotRenderer {
    /// How the matrix looks (Settings › Screen).
    public struct Look: Equatable, Sendable {
        public var fineness = 240, glow = 0.8, afterglow = 0.3
        public init(fineness: Int = 240, glow: Double = 0.8, afterglow: Double = 0.3) {
            (self.fineness, self.glow, self.afterglow) = (fineness, glow, afterglow)
        }
    }

    /// Where the dots are, in px: whole pixels a dot, the rest round the edge.
    public struct Layout: Equatable, Sendable {
        public var w, h, pitch, ox, oy, pxW, pxH: Int

        /// Whole pixels a dot, so every dot is exactly alike; never so few across that a page cannot be laid out (`DotView.relayout`).
        public init(pxW: Int, pxH: Int, fineness: Int) {
            var pitch = max(3, Int((Double(min(pxW, pxH)) / Double(max(fineness, 1))).rounded()))
            while pxW / pitch < 200 && pitch > 3 { pitch -= 1 }
            let w = max(1, min(1600, pxW / pitch)), h = max(1, min(1600, pxH / pitch))
            (self.w, self.h, self.pitch) = (w, h, pitch)
            (ox, oy) = ((pxW - w * pitch) / 2, (pxH - h * pitch) / 2)
            (self.pxW, self.pxH) = (max(pxW, 1), max(pxH, 1))
        }

        /// The dot under a pixel (may be outside the matrix).
        public func dot(_ x: Double, _ y: Double) -> (x: Int, y: Int) {
            (Int(((x - Double(ox)) / Double(pitch)).rounded(.down)), Int(((y - Double(oy)) / Double(pitch)).rounded(.down)))
        }
    }

    public private(set) var layout = Layout(pxW: 1, pxH: 1, fineness: 240)
    public var look = Look()
    /// The picture: `layout.pxW` × `layout.pxH`, B G R X.
    public private(set) var pixels: [UInt32] = [0]

    private var light: [Float] = [], before: [Float] = [], across: [Float] = [], bloom: [Float] = []
    private var level: [Float] = [], radius: [Float] = []
    private var distance: [Float] = [], unlitMask: [Float] = []
    private var frames = 0

    /// pow(v / 255, 1.55): the light a dot's byte gives.
    private static let lightOf: [Float] = (0..<256).map { powf(Float($0) / 255, 1.55) }
    /// pow(c, 1 / 2.2) × 255 for c in 0...1, 4096 steps.
    private static let gamma: [Float] = (0...4096).map { powf(Float($0) / 4096, 1 / 2.2) * 255 }
    /// A little noise, so dark glows do not band (±0.5 / 340 of full scale, in steps of a byte).
    private static let noise: [Float] = {
        var g = SplitMix(seed: 0x6A1A_C5E2)
        return (0..<(64 * 64)).map { _ in (Float(g.next() % 10_000) / 10_000 - 0.5) * 255 / 340 }
    }()
    private static let weights: [Float] = [0.204, 0.180, 0.124, 0.066, 0.028]

    public init() {}

    /// For a window of `pxW` × `pxH` pixels; the matrix size is then `layout.w` × `layout.h`.
    public func resize(pxW: Int, pxH: Int) {
        let l = Layout(pxW: pxW, pxH: pxH, fineness: look.fineness)
        guard l != layout || pixels.count != l.pxW * l.pxH else { return }
        layout = l
        pixels = [UInt32](repeating: 0, count: l.pxW * l.pxH)
        let cells = l.w * l.h * 3
        (light, before, across, bloom) = ([Float](repeating: 0, count: cells), [Float](repeating: 0, count: cells),
                                          [Float](repeating: 0, count: cells), [Float](repeating: 0, count: cells))
        level = [Float](repeating: 0, count: l.w * l.h)
        radius = level
        let p = l.pitch, half = Float(p) / 2
        distance = (0..<(p * p)).map { i in
            let dx = Float(i % p) + 0.5 - half, dy = Float(i / p) + 0.5 - half
            return (dx * dx + dy * dy).squareRoot()
        }
        unlitMask = distance.map { min(1, max(0, Float(p) * 0.3 - $0 + 0.5)) }
        frames = 0
    }

    /// Draw `dots` (RGBA, `layout.w` × `layout.h`, from `DesktopCore.frame`), `dt` seconds after the last frame.
    public func draw(_ dots: [UInt8], dt: Double) {
        let l = layout
        guard dots.count >= l.w * l.h * 4, light.count == l.w * l.h * 3 else { return }
        let decay: Float = frames < 2 || look.afterglow <= 0 ? 0 : Float(pow(0.5, dt / (0.012 + look.afterglow * 0.06)))
        frames += 1
        swap(&light, &before)
        afterglow(dots, decay: decay)
        blur()
        lights(glow: Float(look.glow * 0.42), unlit: 0.0046)
    }

    // MARK: passes

    /// This frame's lights, or what is left of the last one's, whichever is brighter.
    private func afterglow(_ dots: [UInt8], decay: Float) {
        let n = layout.w * layout.h
        dots.withUnsafeBufferPointer { d in
            Self.lightOf.withUnsafeBufferPointer { lut in
                before.withUnsafeBufferPointer { b in
                    light.withUnsafeMutableBufferPointer { o in
                        level.withUnsafeMutableBufferPointer { lv in
                            radius.withUnsafeMutableBufferPointer { r in
                                let pitch = Float(layout.pitch)
                                for i in 0..<n {
                                    var top: Float = 0
                                    for c in 0..<3 {
                                        let v = max(lut[Int(d[i * 4 + c])], b[i * 3 + c] * decay - 0.0004)
                                        o[i * 3 + c] = v
                                        top = max(top, v)
                                    }
                                    let lvl = min(1, max(0, top.squareRoot()))
                                    lv[i] = lvl
                                    r[i] = pitch * (0.315 + 0.125 * lvl)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /// The light that spills: a blur each way, at one value a dot.
    private func blur() {
        let w = layout.w, h = layout.h
        func pass(_ src: [Float], _ dst: inout [Float], dx: Int, dy: Int) {
            src.withUnsafeBufferPointer { s in
                dst.withUnsafeMutableBufferPointer { o in
                    Self.weights.withUnsafeBufferPointer { wt in
                        for y in 0..<h {
                            for x in 0..<w {
                                let at = (y * w + x) * 3
                                var r = s[at] * wt[0], g = s[at + 1] * wt[0], b = s[at + 2] * wt[0]
                                for i in 1..<5 {
                                    let x1 = min(w - 1, max(0, x + dx * i)), y1 = min(h - 1, max(0, y + dy * i))
                                    let x2 = min(w - 1, max(0, x - dx * i)), y2 = min(h - 1, max(0, y - dy * i))
                                    let p = (y1 * w + x1) * 3, q = (y2 * w + x2) * 3
                                    r += (s[p] + s[q]) * wt[i]
                                    g += (s[p + 1] + s[q + 1]) * wt[i]
                                    b += (s[p + 2] + s[q + 2]) * wt[i]
                                }
                                o[at] = r; o[at + 1] = g; o[at + 2] = b
                            }
                        }
                    }
                }
            }
        }
        pass(light, &across, dx: 1, dy: 0)
        pass(across, &bloom, dx: 0, dy: 1)
    }

    /// Every dot a round light on dark glass, with the blurred light around it. Rows in bands, one band a thread, one core
    /// left free (MIDI's sender must never wait for a frame).
    private func lights(glow: Float, unlit: Float) {
        let l = layout
        let bands = max(1, min(ProcessInfo.processInfo.activeProcessorCount - 1, l.pxH / 16))
        let job = Job(l: l, glow: glow, unlit: unlit)
        light.withUnsafeBufferPointer { lt in
            bloom.withUnsafeBufferPointer { bl in
                level.withUnsafeBufferPointer { lv in
                    radius.withUnsafeBufferPointer { rd in
                        distance.withUnsafeBufferPointer { ds in
                            unlitMask.withUnsafeBufferPointer { um in
                                Self.gamma.withUnsafeBufferPointer { gm in
                                    Self.noise.withUnsafeBufferPointer { nz in
                                        pixels.withUnsafeMutableBufferPointer { px in
                                            let io = Buffers(light: lt, bloom: bl, level: lv, radius: rd, distance: ds, unlit: um,
                                                             gamma: gm, noise: nz, pixels: px)
                                            DispatchQueue.concurrentPerform(iterations: bands) { band in
                                                let y0 = l.pxH * band / bands, y1 = l.pxH * (band + 1) / bands
                                                job.rows(y0..<y1, io)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /// What one band reads and writes. Bands write different rows: nothing is shared that is written.
    private struct Buffers: @unchecked Sendable {
        let light, bloom, level, radius, distance, unlit, gamma, noise: UnsafeBufferPointer<Float>
        let pixels: UnsafeMutableBufferPointer<UInt32>
    }

    private struct Job: Sendable {
        let l: Layout, glow: Float, unlit: Float

        func rows(_ ys: Range<Int>, _ b: Buffers) {
            let w = l.w, h = l.h, pitch = l.pitch
            var row = [Float](repeating: 0, count: w * 3)        // the bloom, this pixel row's height, every dot across
            for py in ys {
                // which dot row, where in it, and the bloom between the two dot rows around this height
                let gy = (Float(py) + 0.5 - Float(l.oy)) / Float(pitch)
                let cy = Int(gy.rounded(.down)), sy = py - l.oy - cy * pitch
                let ty = min(Float(h - 1), max(0, gy - 0.5)), y0 = Int(ty), y1 = min(h - 1, y0 + 1), fy = ty - Float(y0)
                for i in 0..<(w * 3) { row[i] = b.bloom[y0 * w * 3 + i] * (1 - fy) + b.bloom[y1 * w * 3 + i] * fy }
                let insideRow = cy >= 0 && cy < h
                let out = py * l.pxW
                for px in 0..<l.pxW {
                    let gx = (Float(px) + 0.5 - Float(l.ox)) / Float(pitch)
                    let cx = Int(gx.rounded(.down))
                    let tx = min(Float(w - 1), max(0, gx - 0.5)), x0 = Int(tx), x1 = min(w - 1, x0 + 1), fx = tx - Float(x0)
                    var r = (row[x0 * 3] * (1 - fx) + row[x1 * 3] * fx) * glow
                    var g = (row[x0 * 3 + 1] * (1 - fx) + row[x1 * 3 + 1] * fx) * glow
                    var bl = (row[x0 * 3 + 2] * (1 - fx) + row[x1 * 3 + 2] * fx) * glow
                    if insideRow && cx >= 0 && cx < w {
                        let cell = cy * w + cx, sx = px - l.ox - cx * pitch
                        let d = b.distance[sy * pitch + sx], lvl = b.level[cell], rad = b.radius[cell]
                        let cover = min(1, max(0, rad - d + 0.5))
                        let core = 1 + 0.22 * lvl * min(1, max(0, 1 - d / max(rad, 0.001)))     // a hot middle
                        let k = cover * core, u = unlit * b.unlit[sy * pitch + sx] * (1 - lvl)
                        r += b.light[cell * 3] * k + u
                        g += b.light[cell * 3 + 1] * k + u
                        bl += b.light[cell * 3 + 2] * k + u
                    }
                    let n = b.noise[(py & 63) * 64 + (px & 63)]
                    b.pixels[out + px] = 0xFF00_0000 | Self.byte(r, b.gamma, n) << 16 | Self.byte(g, b.gamma, n) << 8 | Self.byte(bl, b.gamma, n)
                }
            }
        }

        @inline(__always)
        static func byte(_ c: Float, _ gamma: UnsafeBufferPointer<Float>, _ noise: Float) -> UInt32 {
            let t = min(1, max(0, c / (c * 0.10 + 1)))
            let v = gamma[Int(t * 4096)] + noise + 0.5
            return UInt32(min(255, max(0, v)))
        }
    }
}

/// A small fixed random sequence (the noise is the same every run).
struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
