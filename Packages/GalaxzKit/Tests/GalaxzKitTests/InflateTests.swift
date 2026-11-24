#if canImport(Compression)
import Compression
#endif
import Foundation
import Testing
import OPZModel
@testable import OPZLink

/// Galax-z's own inflate, which Windows uses for everything the OP-Z sends compressed. Checked here on every system;
/// on a Mac also against Apple's.
@Suite struct InflateTests {
    static func bytes(_ hex: String) -> [UInt8] {
        var out: [UInt8] = [], s = hex[...]
        while s.count >= 2 { out.append(UInt8(s.prefix(2), radix: 16)!); s = s.dropFirst(2) }
        return out
    }

    static func inflate(_ raw: [UInt8], max: Int) -> [UInt8]? {
        var out = [UInt8](repeating: 0, count: max)
        guard let n = Inflate.raw(raw, into: &out), n <= max else { return nil }
        return Array(out[..<n])
    }

    // made with Python's zlib, raw deflate (wbits -15)
    static let stored = bytes("012c01d3fea54dca182530bb1d6d132cded6237b2ed91e3f721fcb1971174494d6493c9d5c3460be31201e69fedaa0eee8b9997f5c7c2999fdafe593253cd654af4dfad71427a0aeb3fee9232f8af2211f9ee491c5b10becb5563bfc1e6f93427ecbc8fe2955e5cd8e46dc8ed4b7c2764d2a5a4d767706f85d8690024ad6bda3401be9c8cbccc935f6cd1f61226ae15338ae1a34004d33ba0d246ac04c81b1baf23e3bf9eef5f79f2b4934af87f5520b69b94b0d982e85bb55b672a872637acd7466fcb60e0e8ff18463b0e4b2ba29703474f064ac68f700f5b02b3dc666f45bdeaa2ccaedcd2b5157410e4dee4af2b34f430a073447de636c0e806c957ba684d6431fb5ead7424d09e15d024c5848f23d1fa6f7361d7f618d1532e70e20e2a6668de7f47e8467e546d53ec8e2a1257bdb")
    static let fixed = bytes("cb48cdc9c957c840277514fc0374a31401")
    static let dynamic = bytes("0dc9d10980300c045047b9057401a7097a345235c50bb438bdbedf974e449b5f54b2093a469237f2b1ad6a45b1d3c6bff2e8423a2f98b0476ac1f401")

    @Test func storedBlock() {
        // a stored block is its 5-byte header and then the bytes themselves
        #expect(Self.inflate(Self.stored, max: 300) == Array(Self.stored[5...]))
    }

    @Test func fixedCodes() {
        #expect(Self.inflate(Self.fixed, max: 100) == Array("hello hello hello hello, OP-Z!".utf8))
    }

    @Test func dynamicCodes() {
        #expect(Self.dynamic[0] >> 1 & 3 == 2)
        #expect(Self.inflate(Self.dynamic, max: 100) == Array("the op-z keeps sixteen tracks; galax-z shows them as dots. ".utf8) + [0])
    }

    @Test func tooLongIsSaid() {
        var out = [UInt8](repeating: 0, count: 10)
        #expect(Inflate.raw(Self.fixed, into: &out) == 11)
    }

    @Test func cutShortIsRefused() {
        for n in [0, 1, 5, Self.dynamic.count / 2, Self.dynamic.count - 1] {
            #expect(Self.inflate(Array(Self.dynamic.prefix(n)), max: 100) == nil)
        }
    }

    /// Whatever arrives, it answers and never traps: flipped bits, random bytes, every block type's header.
    @Test func garbageNeverTraps() {
        var g = SystemRandomNumberGenerator()
        for _ in 0..<3000 {
            var b = [Self.stored, Self.fixed, Self.dynamic].randomElement(using: &g)!
            for _ in 0..<Int.random(in: 1...6, using: &g) { b[Int.random(in: 0..<b.count, using: &g)] ^= UInt8.random(in: 1...255, using: &g) }
            _ = Self.inflate(b, max: 400)
            _ = Self.inflate((0..<Int.random(in: 0...200, using: &g)).map { _ in UInt8.random(in: 0...255, using: &g) }, max: 400)
        }
        for first: UInt8 in 0...255 { _ = Self.inflate([first] + [UInt8](repeating: 0xFF, count: 40), max: 64) }
    }

    /// A distance further back than anything written is refused, not read from before the buffer.
    @Test func distanceBeforeTheStartIsRefused() {
        // fixed block: length code 257 (3 bytes) at distance code 0 (1 back) with nothing written yet
        // bits: final 1, type 01, then 257 = 0000001 (7 bits, MSB first), distance 00000, end 0000000
        var w = BitWriter()
        w.put(1, 1); w.put(1, 2); w.code(0b0000001, 7); w.code(0, 5); w.code(0, 7)
        #expect(Self.inflate(w.bytes, max: 10) == nil)
    }

    #if canImport(Compression)
    /// The same bytes as Apple's, for many inputs of every kind, compressed by Apple's own.
    @Test func sameAsApple() throws {
        var g = SystemRandomNumberGenerator()
        let text = Array("Galax-z: the screen the OP-Z never had. Sixteen tracks, sixteen steps, every sound its own animation. ".utf8)
        for round in 0..<120 {
            let n = Int.random(in: 0...70_000, using: &g)
            let input: [UInt8] = switch round % 4 {
            case 0: (0..<n).map { _ in UInt8.random(in: 0...255, using: &g) }                     // stored blocks
            case 1: (0..<n).map { text[$0 % text.count] }                                       // long matches
            case 2: (0..<n).map { _ in UInt8.random(in: 0...3, using: &g) }                     // few symbols
            default: (0..<n).map { i in i % 977 < 400 ? text[(i * 7) % text.count] : UInt8(truncatingIfNeeded: i) }
            }
            var packed = [UInt8](repeating: 0, count: n + n / 2 + 1024)
            let m = compression_encode_buffer(&packed, packed.count, input, input.count, nil, COMPRESSION_ZLIB)
            try #require(m > 0 || n == 0)
            #expect(Self.inflate(Array(packed[..<m]), max: n) == (n == 0 && m == 0 ? nil : input), "round \(round), \(n) bytes")
        }
    }

    #endif

    /// The demo OP-Z's whole project as it comes over the wire: on Windows this is the path it takes (checked by its Adler-32).
    @Test func demoBank() throws {
        let demo = DemoOPZCore.bundled()
        let z = demo.parts.compactMap { try? SysEx.decode($0) }.flatMap { $0.payload.dropFirst(6) }
        try #require(z.count > 6)
        var mine = [UInt8](repeating: 0, count: OPZ.bankSize + 1)
        #expect(Inflate.raw(Array(z[2...]), into: &mine) == OPZ.bankSize)
        let theirs = try #require(Zlib.inflate(z, size: OPZ.bankSize))
        #expect(Array(mine[..<OPZ.bankSize]) == theirs)
        #expect(Zlib.adler32(Array(mine[..<OPZ.bankSize])) == z.suffix(4).reduce(UInt32(0)) { $0 << 8 | UInt32($1) })
    }
}

/// Deflate's bit order: fields lowest bit first, Huffman codes highest bit first.
private struct BitWriter {
    var bytes: [UInt8] = [], n = 0
    mutating func bit(_ b: Int) {
        if n % 8 == 0 { bytes.append(0) }
        bytes[bytes.count - 1] |= UInt8(b & 1) << UInt8(n % 8)
        n += 1
    }
    mutating func put(_ v: Int, _ count: Int) { for i in 0..<count { bit(v >> i) } }
    mutating func code(_ v: Int, _ count: Int) { for i in (0..<count).reversed() { bit(v >> i) } }
}
