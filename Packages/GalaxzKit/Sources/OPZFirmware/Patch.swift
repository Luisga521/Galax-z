#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto        // swift-crypto: the same API, on Windows and Linux
#endif
import Foundation

/// A Galax-z OS patch record (Firmware/patches/*.json; op-free's format plus our own code blocks).
public struct PatchRecord: Codable, Sendable {
    public struct Source: Codable, Sendable { public let size: Int; public let sha256: String; public let crc32: UInt32 }
    public struct Edit: Codable, Sendable {
        public let what: String
        public let device_address, file_offset, expected, new: String
    }
    public struct Block: Codable, Sendable {
        public let what, target, source, data, sha256: String
    }
    public let name, status, description: String
    public let source: Source
    public let edits: [Edit]
    public let blocks: [Block]?
    /// Earlier versions of our block that have been on an OP-Z: never written, only recognised there.
    public var earlier: [Block]?

    /// This record, and as it was with each earlier block.
    var versions: [PatchRecord] {
        [self] + (earlier ?? []).map { PatchRecord(name: name, status: status, description: description, source: source, edits: edits, blocks: [$0]) }
    }

    public var isDraft: Bool { status.uppercased().hasPrefix("DRAFT") }
}

public struct PatchError: Error, CustomStringConvertible { public let description: String }

/// Port of Firmware/tools/patch.py, refusal for refusal.
public enum Patcher {
    /// DDR that nothing in the 1.2.45 OS refers to (Firmware/notes/leds.md).
    public static let free: [ClosedRange<UInt64>] = [0x80C0_0000...0x80FF_FFFF]

    public static func apply(_ original: [UInt8], _ records: [PatchRecord]) throws -> [UInt8] {
        let blocks = try LDR.parse(original)
        let headers = blocks.map { $0.headerOffset..<$0.headerOffset + 16 }
        var out = original, touched: [Range<Int>] = []
        for rec in records {
            if rec.isDraft { throw PatchError(description: "\(rec.name): status is DRAFT") }
            guard rec.source.size == original.count, rec.source.sha256 == Hash.sha256(original),
                  rec.source.crc32 == Hash.crc32(original) else {
                throw PatchError(description: "\(rec.name): the image is not the one the record needs")
            }
            for (i, e) in rec.edits.enumerated() {
                let at = "\(rec.name) edit \(i + 1) (\(e.what))"
                guard let address = UInt32(exactly: try number(e.device_address)), let offset = Int(exactly: try number(e.file_offset)) else {
                    throw PatchError(description: "\(at): an address that cannot be")
                }
                guard let b = LDR.block(of: address, in: blocks) else { throw PatchError(description: "\(at): not in a loaded block") }
                let mapped = b.dataOffset + Int(address - b.target)
                guard mapped == offset else { throw PatchError(description: "\(at): the address is at file offset \(mapped)") }
                let expected = try bytes(e.expected), new = try bytes(e.new)
                guard !new.isEmpty, new.count == expected.count else { throw PatchError(description: "\(at): new must be as long as expected") }
                let span = offset..<offset + new.count
                guard UInt64(address) + UInt64(new.count) <= UInt64(b.target) + UInt64(b.count) else {
                    throw PatchError(description: "\(at): crosses the end of its LDR block")
                }
                if headers.contains(where: { $0.overlaps(span) }) { throw PatchError(description: "\(at): touches an LDR block header") }
                if touched.contains(where: { $0.overlaps(span) }) { throw PatchError(description: "\(at): overlaps another edit") }
                guard Array(out[span]) == expected else { throw PatchError(description: "\(at): the bytes there are not the expected ones") }
                out.replaceSubrange(span, with: new)
                touched.append(span)
            }
            out = try addBlocks(out, rec.blocks ?? [], name: rec.name)
        }
        _ = try LDR.parse(out)
        return out
    }

    /// Insert each block before the FINAL block and raise the stream header's length to match.
    static func addBlocks(_ data: [UInt8], _ new: [PatchRecord.Block], name: String) throws -> [UInt8] {
        guard !new.isEmpty else { return data }
        let parsed = try LDR.parse(data)
        guard let first = parsed.first, let final = parsed.last, first.flags & LDRBlock.first != 0,
              final.flags & LDRBlock.final != 0, final.headerOffset == data.count - 16,
              first.argument == UInt32(data.count - 16) else {
            throw PatchError(description: "\(name): the image is not one FIRST … FINAL stream")
        }
        var used = parsed.filter { $0.count > 0 && $0.flags & LDRBlock.ignore == 0 }
            .map { UInt64($0.target)..<UInt64($0.target) + UInt64($0.count) }
        var inserted: [UInt8] = []
        for (i, blk) in new.enumerated() {
            let at = "\(name) block \(i + 1) (\(blk.what))"
            let target = try number(blk.target), payload = try bytes(blk.data)
            guard target <= UInt64(UInt32.max), payload.count < 64_000_000 else { throw PatchError(description: "\(at): an address that cannot be") }
            guard Hash.sha256(payload) == blk.sha256 else { throw PatchError(description: "\(at): data does not match its sha256") }
            guard !payload.isEmpty, target % 4 == 0, payload.count % 4 == 0 else {
                throw PatchError(description: "\(at): target and size must be 4-byte aligned and not empty")
            }
            let span = target..<target + UInt64(payload.count)
            guard free.contains(where: { $0.contains(span.lowerBound) && $0.contains(span.upperBound - 1) }) else {
                throw PatchError(description: "\(at): not inside a free region")
            }
            if used.contains(where: { $0.overlaps(span) }) { throw PatchError(description: "\(at): overlaps another block") }
            used.append(span)
            inserted += LDR.header(flags: 0x0004, target: UInt32(target), count: UInt32(payload.count)) + payload
        }
        let head = LDR.header(flags: first.flags, target: first.target, count: first.count,
                              argument: first.argument + UInt32(inserted.count))
        return head + data[16..<final.headerOffset] + inserted + data[final.headerOffset...]
    }

    /// The original back out of an image built from these records: their blocks removed, their edits undone.
    public static func unapply(_ image: [UInt8], _ records: [PatchRecord]) -> [UInt8]? {
        var d = image
        for rec in records.reversed() {
            for blk in (rec.blocks ?? []).reversed() {
                guard let blocks = try? LDR.parse(d), let target = try? number(blk.target), let payload = try? bytes(blk.data),
                      let b = blocks.last(where: { UInt64($0.target) == target && Int($0.count) == payload.count }),
                      Array(d[b.dataOffset..<b.dataOffset + payload.count]) == payload, let first = blocks.first else { return nil }
                d.removeSubrange(b.headerOffset..<b.dataOffset + payload.count)
                let head = LDR.header(flags: first.flags, target: first.target, count: first.count,
                                      argument: first.argument - UInt32(16 + payload.count))
                d.replaceSubrange(0..<16, with: head)
            }
            for e in rec.edits {
                guard let offset = (try? number(e.file_offset)).flatMap({ Int(exactly: $0) }), offset < d.count, let new = try? bytes(e.new), let old = try? bytes(e.expected),
                      offset + new.count <= d.count, Array(d[offset..<offset + new.count]) == new else { return nil }
                d.replaceSubrange(offset..<offset + new.count, with: old)
            }
        }
        return d
    }

    static func number(_ s: String) throws -> UInt64 {
        guard let v = UInt64(s.lowercased().replacingOccurrences(of: "0x", with: ""), radix: 16) else {
            throw PatchError(description: "not a hex number: \(s)")
        }
        return v
    }

    static func bytes(_ s: String) throws -> [UInt8] {
        let h = s.filter { !$0.isWhitespace }
        guard h.count % 2 == 0 else { throw PatchError(description: "odd hex string") }
        var out: [UInt8] = [], i = h.startIndex
        out.reserveCapacity(h.count / 2)
        while i < h.endIndex {
            let j = h.index(i, offsetBy: 2)
            guard let b = UInt8(h[i..<j], radix: 16) else { throw PatchError(description: "bad hex: \(h[i..<j])") }
            out.append(b)
            i = j
        }
        return out
    }
}

public enum Hash {
    public static func sha256(_ d: [UInt8]) -> String { SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined() }

    private static let table: [UInt32] = (0..<256).map { n in
        (0..<8).reduce(UInt32(n)) { c, _ in c & 1 == 1 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
    }

    /// zlib's CRC-32: what TE writes as `os.crc32`, in decimal.
    public static func crc32(_ d: [UInt8]) -> UInt32 {
        ~d.reduce(UInt32.max) { table[Int(($0 ^ UInt32($1)) & 0xFF)] ^ ($0 >> 8) }
    }
}
