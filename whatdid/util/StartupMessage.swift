// whatdid?

enum StartupMessage: Int {
    case updated
    
    var humanReadable: String {
        switch self {
        case .updated:
            return "Updated!"
        }
    }
}
