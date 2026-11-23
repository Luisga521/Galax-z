/// The type of the matrix: 4 × 5 for labels, 5 × 7 to read, and larger ones drawn along the 5 × 7's own lines with a round
/// pen, for names and numbers. Capitals, figures and signs; small letters come out as capitals.
public final class DotFont: Sendable {
    public struct Glyph: Sendable {
        /// Where its dots are, and how lit each is.
        public let dots: [(x: Int, y: Int, a: Double)]
        public let advance: Int
    }

    public let height: Int
    private let gap: Int
    private let glyphs: [UInt32: Glyph]
    private let missing: Glyph

    public static let tiny = DotFont(tinyArt, columns: 5, rows: 5, figures: 4)
    public static let small = DotFont(smallArt, columns: 5, rows: 7)
    public static let big = DotFont(smallArt, columns: 5, rows: 7, scale: 2)
    public static let huge = DotFont(smallArt, columns: 5, rows: 7, scale: 4)

    /// `art`: a glyph's rows from the top as hex, the leftmost dot the highest bit. `figures`: how wide figures are, all alike.
    init(_ art: [(String, String)], columns: Int, rows: Int, scale k: Int = 1, figures: Int? = nil) {
        var all: [UInt32: Glyph] = [:]
        for (names, hex) in art {
            let digits = Array(hex.filter { $0 != " " })
            let per = digits.count / rows
            var grid = (0..<rows).map { r -> [Bool] in
                let v = Int(String(digits[(r * per)..<((r + 1) * per)]), radix: 16) ?? 0
                return (0..<columns).map { v >> (columns - 1 - $0) & 1 == 1 }
            }
            // a glyph takes its own width, so text reads evenly; figures stay put
            let used = (0..<columns).filter { c in grid.contains { $0[c] } }
            let figure = names.contains { $0.isASCII && $0.isNumber }
            let range = figure ? 0...((figures ?? columns) - 1) : (used.first ?? 0)...(used.last ?? columns / 2)
            grid = grid.map { Array($0[range]) }
            let dots = k == 1 ? Self.plain(grid) : Self.penned(grid, k)
            for s in names.unicodeScalars { all[s.value] = Glyph(dots: dots, advance: grid[0].count * k + k) }
        }
        all[32] = Glyph(dots: [], advance: 3 * k)
        glyphs = all
        missing = all[UInt32(UnicodeScalar("?").value)] ?? Glyph(dots: [], advance: columns + 1)
        height = rows * k
        gap = k
    }

    static func plain(_ g: [[Bool]]) -> [(x: Int, y: Int, a: Double)] {
        g.enumerated().flatMap { y, row in row.enumerated().compactMap { x, on in on ? (x, y, 1.0) : nil } }
    }

    /// Every lit cell joined to its lit neighbours by a round line.
    static func penned(_ g: [[Bool]], _ k: Int) -> [(x: Int, y: Int, a: Double)] {
        let h = g.count, w = g[0].count
        func at(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < w && y < h && g[y][x] }
        func mid(_ v: Int) -> Double { (Double(v) + 0.5) * Double(k) - 0.5 }
        var lines: [(Double, Double, Double, Double)] = []
        for y in 0..<h { for x in 0..<w where at(x, y) {
            lines.append((mid(x), mid(y), mid(x), mid(y)))
            if at(x + 1, y) { lines.append((mid(x), mid(y), mid(x + 1), mid(y))) }
            if at(x, y + 1) { lines.append((mid(x), mid(y), mid(x), mid(y + 1))) }
            for d in [-1, 1] where at(x + d, y + 1) && !at(x + d, y) && !at(x, y + 1) { lines.append((mid(x), mid(y), mid(x + d), mid(y + 1))) }
        } }
        let r = Double(k) * 0.47
        var out: [(x: Int, y: Int, a: Double)] = []
        for y in 0..<h * k { for x in 0..<w * k {
            var best = Double.infinity
            for (ax, ay, bx, by) in lines {
                let dx = bx - ax, dy = by - ay, px = Double(x) - ax, py = Double(y) - ay, n = dx * dx + dy * dy
                let t = n == 0 ? 0 : min(1, max(0, (px * dx + py * dy) / n))
                let ex = px - dx * t, ey = py - dy * t
                best = min(best, ex * ex + ey * ey)
            }
            let a = min(1, max(0, r + 0.5 - best.squareRoot()))
            if a > 0.08 { out.append((x, y, a)) }
        } }
        return out
    }

    @inline(__always)
    func glyph(_ s: UnicodeScalar) -> Glyph {
        let v = s.value
        return glyphs[v >= 97 && v <= 122 ? v - 32 : v] ?? missing
    }

    public func width(_ s: String) -> Int {
        var w = 0
        for u in s.unicodeScalars { w += glyph(u).advance }
        return max(0, w - gap)
    }

    /// The longest start of `s` that fits, with a dot for what is left out.
    public func fitted(_ s: String, _ w: Int) -> String {
        if width(s) <= w { return s }
        var out = s
        while !out.isEmpty, width(out + ".") > w { out.removeLast() }
        return out.trimmingSpaces + "."
    }

    static let smallArt: [(String, String)] = [
        ("A", "0E11111F111111"), ("B", "1E11111E11111E"), ("C", "0E11101010110E"), ("D", "1E11111111111E"),
        ("E", "1F10101E10101F"), ("F", "1F10101E101010"), ("G", "0E11101711110F"), ("H", "1111111F111111"),
        ("I", "0E04040404040E"), ("J", "0702020202120C"), ("K", "11121418141211"), ("L", "1010101010101F"),
        ("M", "111B1515111111"), ("N", "11191513111111"), ("O", "0E11111111110E"), ("P", "1E11111E101010"),
        ("Q", "0E11111115120D"), ("R", "1E11111E141211"), ("S", "0F10100E01011E"), ("T", "1F040404040404"),
        ("U", "1111111111110E"), ("V", "11111111110A04"), ("W", "11111115151B11"), ("X", "11110A040A1111"),
        ("Y", "11110A04040404"), ("Z", "1F01020408101F"),
        ("0", "0E11111111110E"), ("1", "040C040404040E"), ("2", "0E11010608101F"), ("3", "1F02040201110E"),
        ("4", "02060A121F0202"), ("5", "1F101E0101110E"), ("6", "0608101E11110E"), ("7", "1F010204080808"),
        ("8", "0E11110E11110E"), ("9", "0E11110F01020C"),
        (".", "00000000000C0C"), (",", "000000000C0408"), (":", "000C0C000C0C00"), (";", "000C0C000C0408"),
        ("-−–", "0000001F000000"), ("—", "0000001F000000"), ("+", "0004041F040400"), ("/", "00010204081000"),
        ("#", "0A0A1F0A1F0A0A"), ("%", "18190204081303"), ("!", "04040404000004"), ("?", "0E110102040004"),
        ("(", "02040808080402"), (")", "08040202020408"), ("[", "0E08080808080E"), ("]", "0E02020202020E"),
        ("&", "0C12140815120D"), ("'’", "0C040800000000"), ("\"“”", "0A0A0A00000000"), ("*", "0004150E150400"),
        ("=", "00001F001F0000"), ("_", "0000000000001F"), ("<‹", "02040810080402"), (">›", "08040201020408"),
        ("·", "0000000C0C0000"), ("×", "00110A040A1100"), ("…", "00000000000015"), ("@", "0E11171517100E"),
        ("$", "040F140E051E04"), ("|", "04040404040404"), ("°", "0C12120C000000"), ("~", "00000815020000"),
        ("▶", "10181C1E1C1810"), ("■", "001F1F1F1F1F00"), ("●", "000E1F1F1F0E00"), ("○", "000E1111110E00"),
        ("↑", "040E1504040404"), ("↓", "0404040415" + "0E04"), ("→", "0004021F020400"), ("←", "0004081F080400"),
        ("✓", "00010102140800"),
    ]

    static let tinyArt: [(String, String)] = [
        ("A", "0C121E1212"), ("B", "1C121C121C"), ("C", "0E1010100E"), ("D", "1C1212121C"), ("E", "1E101C101E"), ("F", "1E101C1010"),
        ("G", "0E1016120E"), ("H", "12121E1212"), ("I", "0E0404040E"), ("J", "020202120C"), ("K", "1214181412"), ("L", "101010101E"),
        ("M", "111B151111"), ("N", "121A161212"), ("O", "0C1212120C"), ("P", "1C121C1010"), ("Q", "0C1212140A"), ("R", "1C121C1412"),
        ("S", "0E100C021C"), ("T", "1F04040404"), ("U", "121212120C"), ("V", "11110A0A04"), ("W", "1111151B11"), ("X", "110A040A11"),
        ("Y", "110A040404"), ("Z", "1E0204081E"),
        ("0", "0C1212120C"), ("1", "040C04040E"), ("2", "1C020C101E"), ("3", "1C020C021C"), ("4", "12121E0202"), ("5", "1E101C021C"),
        ("6", "0C101C120C"), ("7", "1E02040808"), ("8", "0C120C120C"), ("9", "0C120E020C"),
        (".", "0000000008"), (",", "0000000810"), (":", "0008000800"), ("-−–—", "00000E0000"), ("+", "00040E0400"), ("/", "0204080810"),
        ("%", "1204080812"), ("#", "0A1F0A1F0A"), ("'’", "0808000000"), ("!", "0808080008"), ("?", "1C020C0008"), ("(", "0408080804"),
        (")", "0804040408"), ("&", "0814081A0D"), ("·", "0000080000"), ("×", "000A040A00"), ("=", "000E000E00"), (">›", "0804020408"),
        ("<‹", "0204080402"), ("_", "000000001E"), ("…", "0000000015"), ("*", "000A040A00"), ("[", "0C0808080C"), ("]", "0C0404040C"),
        ("▶", "10181C1810"), ("■", "001C1C1C00"), ("●", "00081C0800"), ("↑", "040E150404"), ("↓", "0404150E04"), ("→", "04021F0204"),
        ("←", "04081F0804"), ("✓", "0102140800"), ("|", "0404040404"), ("°", "0814080000"), ("$", "0E140E051E"), ("@", "0C121A100E"), ("\"“”", "0A0A000000"),
    ]
}

extension String {
    var trimmingSpaces: String {
        var s = self
        while s.last == " " { s.removeLast() }
        return s
    }
}
