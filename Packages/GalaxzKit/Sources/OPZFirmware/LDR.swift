import Foundation

/// The OP-Z's OS image is a Blackfin+ LDR boot stream: 16-byte block headers
/// (`flags u16 | xor u8 | 0xAD | target u32 | count u32 | argument u32`, little-endian), each followed by `count`
/// payload bytes unless it is a FILL block. Port of Firmware/tools/ldr.py: the same checks the OP-Z's loader makes.
public struct LDRBlock: Sendable, Equatable {
    public let index, headerOffset: Int
    public let flags: UInt16
    public let target, count, argument: UInt32

    public static let fill: UInt16 = 0x0100, ignore: UInt16 = 0x1000, first: UInt16 = 0x4000, final: UInt16 = 0x8000

    public var hasPayload: Bool { flags & Self.fill == 0 }
    public var loaded: Bool { hasPayload && flags & Self.ignore == 0 && count > 0 }
    public var dataOffset: Int { headerOffset + 16 }
}

public struct LDRError: Error, CustomStringConvertible { public let description: String }

public enum LDR {
    public static func parse(_ d: [UInt8]) throws -> [LDRBlock] {
        var blocks: [LDRBlock] = [], at = 0
        while at < d.count {
            guard at + 16 <= d.count else { throw LDRError(description: "truncated header at 0x\(hex(at))") }
            guard d[at + 3] == 0xAD else { throw LDRError(description: "bad header at 0x\(hex(at)): byte 3 is not 0xAD") }
            guard d[at..<at + 16].reduce(0, ^) == 0 else { throw LDRError(description: "bad header checksum at 0x\(hex(at))") }
            let b = LDRBlock(index: blocks.count, headerOffset: at, flags: u16(d, at), target: u32(d, at + 4),
                             count: u32(d, at + 8), argument: u32(d, at + 12))
            blocks.append(b)
            at += 16 + (b.hasPayload ? Int(b.count) : 0)
        }
        guard at == d.count else { throw LDRError(description: "the walk ends at 0x\(hex(at)), not at the end of the file") }
        return blocks
    }

    /// The last loaded block covering `address` (a later block overwrites an earlier one).
    public static func block(of address: UInt32, in blocks: [LDRBlock]) -> LDRBlock? {
        blocks.last { $0.loaded && $0.target <= address && UInt64(address) < UInt64($0.target) + UInt64($0.count) }
    }

    public static func offset(of address: UInt32, in blocks: [LDRBlock]) throws -> Int {
        guard let b = block(of: address, in: blocks) else {
            throw LDRError(description: "0x\(String(address, radix: 16)) is not in any loaded block")
        }
        return b.dataOffset + Int(address - b.target)
    }

    public static func header(flags: UInt16, target: UInt32, count: UInt32, argument: UInt32 = 0) -> [UInt8] {
        var h: [UInt8] = [UInt8(flags & 0xFF), UInt8(flags >> 8), 0, 0xAD]
        h += le(target) + le(count) + le(argument)
        h[2] = h.reduce(0, ^)   // the whole header XORs to zero
        return h
    }

    static func u16(_ d: [UInt8], _ i: Int) -> UInt16 { UInt16(d[i]) | UInt16(d[i + 1]) << 8 }
    static func u32(_ d: [UInt8], _ i: Int) -> UInt32 {
        UInt32(d[i]) | UInt32(d[i + 1]) << 8 | UInt32(d[i + 2]) << 16 | UInt32(d[i + 3]) << 24
    }
    static func le(_ v: UInt32) -> [UInt8] { [UInt8(v & 0xFF), UInt8(v >> 8 & 0xFF), UInt8(v >> 16 & 0xFF), UInt8(v >> 24)] }
    static func hex(_ v: Int) -> String { String(v, radix: 16) }
}
