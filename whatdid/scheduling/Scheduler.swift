// whatdid?

import Foundation

protocol Scheduler {
    var now: Date { get }
    func schedule(at: Date, _ block: @escaping () -> Void)
    func schedule(after: TimeInterval, _ block: @escaping () -> Void)
}
