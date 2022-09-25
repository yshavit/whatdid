// whatdid?

class PushableString {
    private(set) var string = ""
    private var levels = [Int]()

    func with(_ other: String, run: () -> Void) {
        push(other)
        run()
        pop()
    }

    func push(_ other: String) {
        levels.append(other.count)
        string += other
    }
    
    func pop() {
        if let last = levels.popLast() {
            let sub = string.dropLast(last)
            string = String(sub)
        }
    }
}