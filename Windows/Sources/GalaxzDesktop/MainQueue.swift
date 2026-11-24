import Foundation

/// The window's thread, for work done elsewhere (a firmware write, a download): what `MainActor.run` is on the Mac.
/// Posted from any thread; run by the window's loop at its next turn (`drain`), in the order posted.
public final class MainQueue: @unchecked Sendable {
    private let lock = NSLock()
    private var jobs: [() -> Void] = []

    public init() {}

    public func post(_ job: @escaping () -> Void) {
        lock.lock()
        jobs.append(job)
        lock.unlock()
    }

    /// Run what has been posted. True if there was anything.
    @discardableResult
    public func drain() -> Bool {
        lock.lock()
        let now = jobs
        jobs = []
        lock.unlock()
        for j in now { j() }
        return !now.isEmpty
    }
}
