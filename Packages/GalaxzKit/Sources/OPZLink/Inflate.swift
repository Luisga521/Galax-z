/// Raw deflate (RFC 1951) in plain Swift, for a system with neither Apple's Compression nor a zlib of its own (Windows).
///
/// What it reads comes from outside (the OP-Z, or whatever is on the cable), so it trusts nothing: every length, distance
/// and code is checked, the output never grows past the buffer it is given, and a stream that is not well formed gives
/// nil. It decodes one bit at a time, after Mark Adler's puff: slow next to zlib, and plenty for the OP-Z's few hundred kB.
enum Inflate {
    /// Decode `src` into `out`. The number of bytes written; `out.count + 1` if the stream holds more than `out` can;
    /// nil if it is not well-formed raw deflate.
    static func raw(_ src: [UInt8], into out: inout [UInt8]) -> Int? {
        var s = Reader(src: src, capacity: out.count)
        do {
            try out.withUnsafeMutableBufferPointer { buf in
                var last = false
                while !last {
                    last = try s.bits(1) == 1
                    switch try s.bits(2) {
                    case 0: try s.stored(buf)
                    case 1: try s.codes(buf, Self.fixed.lengths, Self.fixed.distances)
                    case 2: let (l, d) = try s.dynamic(); try s.codes(buf, l, d)
                    default: throw Bad.stream
                    }
                }
            }
        } catch Bad.full {
            return out.count + 1
        } catch {
            return nil
        }
        return s.written
    }

    enum Bad: Error { case stream, full }

    /// A canonical Huffman code: how many codes of each length, and the symbols in code order.
    struct Code {
        var count = [Int](repeating: 0, count: 16)
        var symbol: [Int]

        /// From each symbol's code length (0: unused). `left` < 0: over-subscribed; > 0: incomplete.
        init(_ lengths: ArraySlice<Int>, left: inout Int) {
            symbol = [Int](repeating: 0, count: lengths.count)
            for l in lengths { count[l] += 1 }
            left = 1
            if count[0] == lengths.count { left = 0; return }      // no codes: complete, and nothing can be decoded
            for len in 1...15 {
                left <<= 1
                left -= count[len]
                if left < 0 { return }
            }
            var offs = [Int](repeating: 0, count: 16)
            for len in 1..<15 { offs[len + 1] = offs[len] + count[len] }
            for (sym, l) in lengths.enumerated() where l != 0 {
                symbol[offs[l]] = sym
                offs[l] += 1
            }
        }
    }

    static let fixed: (lengths: Code, distances: Code) = {
        var lengths = [Int](repeating: 8, count: 288), left = 0
        for i in 144..<256 { lengths[i] = 9 }
        for i in 256..<280 { lengths[i] = 7 }
        let l = Code(lengths[...], left: &left)
        let d = Code([Int](repeating: 5, count: 30)[...], left: &left)
        return (l, d)
    }()

    static let lengthBase = [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258]
    static let lengthExtra = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0]
    static let distanceBase = [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073,
                               4097, 6145, 8193, 12289, 16385, 24577]
    static let distanceExtra = [0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13]
    static let order = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]

    struct Reader {
        let src: [UInt8]
        let capacity: Int
        var at = 0, bitBuffer: UInt32 = 0, bitCount = 0
        var written = 0

        init(src: [UInt8], capacity: Int) { (self.src, self.capacity) = (src, capacity) }

        /// The next `n` bits (0...16), first bit lowest.
        mutating func bits(_ n: Int) throws -> Int {
            while bitCount < n {
                guard at < src.count else { throw Bad.stream }
                bitBuffer |= UInt32(src[at]) << UInt32(bitCount)
                at += 1
                bitCount += 8
            }
            let v = Int(bitBuffer & ((1 << UInt32(n)) - 1))
            bitBuffer >>= UInt32(n)
            bitCount -= n
            return v
        }

        mutating func put(_ buf: UnsafeMutableBufferPointer<UInt8>, _ b: UInt8) throws {
            guard written < capacity else { throw Bad.full }
            buf[written] = b
            written += 1
        }

        /// A block kept as it is: the rest of this byte dropped, its length and that length's complement, the bytes.
        mutating func stored(_ buf: UnsafeMutableBufferPointer<UInt8>) throws {
            bitBuffer = 0
            bitCount = 0
            guard at + 4 <= src.count else { throw Bad.stream }
            let len = Int(src[at]) | Int(src[at + 1]) << 8, nlen = Int(src[at + 2]) | Int(src[at + 3]) << 8
            at += 4
            guard len == ~nlen & 0xFFFF, at + len <= src.count else { throw Bad.stream }
            for i in 0..<len { try put(buf, src[at + i]) }
            at += len
        }

        mutating func decode(_ h: Code) throws -> Int {
            var code = 0, first = 0, index = 0
            for len in 1...15 {
                code |= try bits(1)
                let count = h.count[len]
                if code - count < first { return h.symbol[index + (code - first)] }
                index += count
                first += count
                first <<= 1
                code <<= 1
            }
            throw Bad.stream            // ran out of code lengths: not a code of this table
        }

        mutating func codes(_ buf: UnsafeMutableBufferPointer<UInt8>, _ lengths: Code, _ distances: Code) throws {
            while true {
                var sym = try decode(lengths)
                if sym < 256 { try put(buf, UInt8(sym)); continue }
                if sym == 256 { return }
                sym -= 257
                guard sym < 29 else { throw Bad.stream }
                let len = Inflate.lengthBase[sym] + (try bits(Inflate.lengthExtra[sym]))
                let dsym = try decode(distances)
                guard dsym < 30 else { throw Bad.stream }
                let dist = Inflate.distanceBase[dsym] + (try bits(Inflate.distanceExtra[dsym]))
                guard dist <= written else { throw Bad.stream }        // further back than anything written
                for _ in 0..<len { try put(buf, buf[written - dist]) }
            }
        }

        /// The block's own codes: lengths of the code-length code, then the literal/length and distance lengths with it.
        mutating func dynamic() throws -> (Code, Code) {
            let nlen = try bits(5) + 257, ndist = try bits(5) + 1, ncode = try bits(4) + 4
            guard nlen <= 286, ndist <= 30 else { throw Bad.stream }
            var lengths = [Int](repeating: 0, count: 19)
            for i in 0..<ncode { lengths[Inflate.order[i]] = try bits(3) }
            var left = 0
            let lencode = Code(lengths[...], left: &left)
            guard left == 0 else { throw Bad.stream }              // the code-length code must be complete

            lengths = [Int](repeating: 0, count: nlen + ndist)
            var i = 0
            while i < nlen + ndist {
                var sym = try decode(lencode)
                if sym < 16 { lengths[i] = sym; i += 1; continue }
                var repeats: Int
                if sym == 16 {
                    guard i > 0 else { throw Bad.stream }           // nothing to repeat
                    sym = lengths[i - 1]
                    repeats = 3 + (try bits(2))
                } else if sym == 17 {
                    sym = 0
                    repeats = 3 + (try bits(3))
                } else {
                    sym = 0
                    repeats = 11 + (try bits(7))
                }
                guard i + repeats <= nlen + ndist else { throw Bad.stream }
                for _ in 0..<repeats { lengths[i] = sym; i += 1 }
            }
            guard lengths[256] != 0 else { throw Bad.stream }      // no end-of-block code
            let l = Code(lengths[0..<nlen], left: &left)
            // incomplete only when there is one code, as zlib allows
            guard left >= 0, left == 0 || nlen - l.count[0] == 1 else { throw Bad.stream }
            let d = Code(lengths[nlen..<nlen + ndist], left: &left)
            guard left >= 0, left == 0 || ndist - d.count[0] == 1 else { throw Bad.stream }
            return (l, d)
        }
    }
}
