/// The scales keys are held to (TO-2's).
public enum Scale: Int, CaseIterable, Codable, Sendable {
    case off, major, minor, penta, minPenta, blues, dorian, mixo, lydian, phrygian, harmMinor, ukrDorian, dblHarmMinor, harmMajor, dblHarmMajor, hirajoshi, inSen, iwato, yo, ryukyu

    public var name: String {
        ["OFF", "MAJOR", "MINOR", "PENTA", "MIN PENTA", "BLUES", "DORIAN", "MIXO", "LYDIAN", "PHRYGIAN", "HARM MIN", "UKR DORIAN", "DBL HARM MIN", "HARM MAJOR",
         "DBL HARM MAJ", "HIRAJOSHI", "IN SEN", "IWATO", "YO", "RYUKYU"][rawValue]
    }
    public var steps: [Int] {
        [Array(0..<12), [0, 2, 4, 5, 7, 9, 11], [0, 2, 3, 5, 7, 8, 10], [0, 2, 4, 7, 9], [0, 3, 5, 7, 10], [0, 3, 5, 6, 7, 10], [0, 2, 3, 5, 7, 9, 10], [0, 2, 4, 5, 7, 9, 10],
         [0, 2, 4, 6, 7, 9, 11], [0, 1, 3, 5, 7, 8, 10], [0, 2, 3, 5, 7, 8, 11], [0, 2, 3, 6, 7, 9, 10], [0, 2, 3, 6, 7, 8, 11], [0, 2, 4, 5, 7, 8, 11], [0, 1, 4, 5, 7, 8, 11],
         [0, 2, 3, 7, 8], [0, 1, 5, 7, 10], [0, 1, 5, 6, 10], [0, 2, 5, 7, 9], [0, 4, 5, 7, 11]][rawValue]
    }

    /// The note `i` degrees up from the tonic at `base`.
    public func note(_ i: Int, base: Int) -> Int {
        let n = steps.count, o = i >= 0 ? i / n : (i - n + 1) / n
        return base + 12 * o + steps[i - o * n]
    }
    public func has(_ note: Int, tonic: Int) -> Bool { steps.contains((((note - tonic) % 12) + 12) % 12) }
    /// The nearest note of the scale; of two, the lower.
    public func snap(_ note: Int, tonic: Int) -> Int {
        for d in 0..<12 { if has(note - d, tonic: tonic) { return note - d }; if has(note + d, tonic: tonic) { return note + d } }
        return note
    }
}
