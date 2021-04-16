// whatdid?

enum OpenReason {
    case manual
    case scheduled
    
    var description: String {
        return String(describing: self)
    }
}
