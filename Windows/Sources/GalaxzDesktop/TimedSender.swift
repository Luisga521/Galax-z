import Foundation

/// One thread sends everything to the OP-Z, each message at its time: a SysEx (time 0) goes out whole before anything else
/// (`MidiLink.Sender` on Android). Times are seconds of `clock`, the one the core counts in.
public final class TimedSender: @unchecked Sendable {
    private struct Message { let at: Double, seq: Int, bytes: [UInt8] }

    private let condition = NSCondition()
    private var queue: [Message] = []         // kept in order of (at, seq)
    private var seq = 0
    private var running = true
    private let send: ([UInt8]) -> Void
    private let clock: () -> Double

    /// `send` is called on the sender's own thread, one message at a time.
    public init(clock: @escaping () -> Double, send: @escaping ([UInt8]) -> Void) {
        self.clock = clock
        self.send = send
        let t = Thread { [weak self] in self?.run() }
        t.name = "galaxz-midi-out"
        t.qualityOfService = .userInteractive
        t.start()
    }

    public func add(_ messages: [(at: Double, bytes: [UInt8])]) {
        guard !messages.isEmpty else { return }
        condition.lock()
        for m in messages where !m.bytes.isEmpty {
            let msg = Message(at: max(0, m.at), seq: seq, bytes: m.bytes)
            seq += 1
            let i = queue.firstIndex { ($0.at, $0.seq) > (msg.at, msg.seq) } ?? queue.count
            queue.insert(msg, at: i)
        }
        condition.signal()
        condition.unlock()
    }

    /// Forget what has not gone out (the OP-Z went away).
    public func clear() {
        condition.lock()
        queue.removeAll()
        condition.unlock()
    }

    public func stop() {
        condition.lock()
        running = false
        condition.signal()
        condition.unlock()
    }

    private func run() {
        while true {
            condition.lock()
            guard running else { condition.unlock(); return }
            guard let head = queue.first else { condition.wait(); condition.unlock(); continue }
            let wait = head.at - clock()
            if wait > 0.004 {
                // the system's timers oversleep by a millisecond or more: wake early, then watch the clock
                _ = condition.wait(until: Date(timeIntervalSinceNow: wait - 0.003))
                condition.unlock()
                continue
            }
            if wait > 0 { condition.unlock(); while clock() < head.at {}; continue }     // at most 4 ms
            queue.removeFirst()
            condition.unlock()
            send(head.bytes)
        }
    }
}
