// SPDX-License-Identifier: MIT
// Derived from OP-FREE: a Swift port of core/src/sysex.ts
// Copyright (c) 2026 Lourens Smit and the op-z-engines contributors (OP-FREE)
// Copyright (c) 2026 Luis Tosado (this version of it)

#if canImport(Compression)
import Compression
#else
import CZlib
/// zlib's own (inside `Zlib`, `inflate` is ours).
private func zlibInflate(_ z: inout z_stream, _ flush: Int32) -> Int32 { inflate(&z, flush) }
#endif

/// OP-Z SysEx framing and the packed-7 encoding. Port of op-free's `core/src/sysex.ts`.
public enum SysEx {
    public static let teHeader: [UInt8] = [0xF0, 0x00, 0x20, 0x76, 0x01]

    public struct Frame: Equatable, Sendable {
        public var id: UInt8
        public var payload: [UInt8]
    }

    public enum Failure: Error, Equatable { case invalidFrame, eightBitData }

    /// Pack 8-bit bytes into groups of a high-bit mask byte and seven 7-bit bytes.
    public static func pack7(_ source: [UInt8]) -> [UInt8] {
        var out: [UInt8] = []
        out.reserveCapacity(source.count + source.count / 7 + 1)
        var start = 0
        while start < source.count {
            let chunk = source[start..<min(start + 7, source.count)]
            var mask: UInt8 = 0
            for (bit, byte) in chunk.enumerated() { mask |= (byte >> 7) << bit }
            out.append(mask)
            out.append(contentsOf: chunk.map { $0 & 0x7F })
            start += 7
        }
        return out
    }

    public static func unpack7(_ source: ArraySlice<UInt8>) throws -> [UInt8] {
        if source.contains(where: { $0 > 0x7F }) { throw Failure.eightBitData }
        var out: [UInt8] = []
        out.reserveCapacity(source.count * 7 / 8)
        var start = source.startIndex
        while start < source.endIndex {
            let end = min(start + 8, source.endIndex)
            let mask = source[start]
            for (bit, byte) in source[(start + 1)..<end].enumerated() { out.append(byte | ((mask >> bit) & 1) << 7) }
            start = end
        }
        return out
    }

    public static func frame(_ id: UInt8, _ payload: [UInt8] = []) -> [UInt8] {
        precondition(id <= 0x7F, "message id must be a 7-bit MIDI data byte")
        return teHeader + [id] + pack7(payload) + [0xF7]
    }

    public static func decode(_ data: [UInt8]) throws -> Frame {
        guard data.count >= 7, data.starts(with: teHeader), data.last == 0xF7 else { throw Failure.invalidFrame }
        return Frame(id: data[5], payload: try unpack7(data[6..<(data.count - 1)]))
    }
}

/// zlib members (RFC 1950): what the OP-Z compresses the bank and the global block into.
public enum Zlib {
    /// Inflate a whole zlib member to exactly `size` bytes, checking its Adler-32; nil if anything is off.
    public static func inflate(_ data: [UInt8], size: Int) -> [UInt8]? {
        guard let out = inflate(data, maxSize: size), out.count == size else { return nil }
        return out
    }

    /// Inflate a whole zlib member of at most `maxSize` bytes, checking its Adler-32; nil if anything is off.
    public static func inflate(_ data: [UInt8], maxSize: Int) -> [UInt8]? {
        guard data.count >= 6, data[0] & 0x0F == 8, (Int(data[0]) << 8 | Int(data[1])) % 31 == 0,
              data[1] & 0x20 == 0 else { return nil } // deflate, valid header check, no preset dictionary
        let raw = Array(data[2...])
        var out = [UInt8](repeating: 0, count: maxSize + 1) // one spare byte: a longer stream fills it and is refused
        let n = rawInflate(raw, into: &out)
        guard n <= maxSize else { return nil }
        out.removeLast(out.count - n)
        let tail = data.suffix(4).reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
        return adler32(out) == tail ? out : nil
    }

    /// Raw deflate (no header, no checksum) into `out`; how many bytes came out (`out.count` or more: too long).
    private static func rawInflate(_ raw: [UInt8], into out: inout [UInt8]) -> Int {
        #if canImport(Compression)
        out.withUnsafeMutableBufferPointer { dst in
            raw.withUnsafeBufferPointer { src in
                compression_decode_buffer(dst.baseAddress!, dst.count, src.baseAddress!, src.count, nil, COMPRESSION_ZLIB)
            }
        }
        #else
        // the system's zlib, told the stream has no header (window bits -15), as Apple's COMPRESSION_ZLIB reads it
        var z = z_stream()
        guard inflateInit2_(&z, -15, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else { return Int.max }
        defer { inflateEnd(&z) }
        var input = raw
        return input.withUnsafeMutableBufferPointer { src in
            out.withUnsafeMutableBufferPointer { dst in
                z.next_in = src.baseAddress
                z.avail_in = uInt(src.count)
                z.next_out = dst.baseAddress
                z.avail_out = uInt(dst.count)
                let r = zlibInflate(&z, Z_FINISH)
                return r == Z_STREAM_END || r == Z_BUF_ERROR || r == Z_OK ? Int(z.total_out) : Int.max
            }
        }
        #endif
    }

    public static func adler32(_ data: [UInt8]) -> UInt32 {
        var a: UInt32 = 1, b: UInt32 = 0
        var i = 0
        while i < data.count {
            let end = min(i + 5552, data.count) // the largest run before the sums can overflow
            while i < end { a += UInt32(data[i]); b += a; i += 1 }
            a %= 65521; b %= 65521
        }
        return b << 16 | a
    }
}
