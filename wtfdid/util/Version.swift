import Cocoa

class Version: NSObject {
    static let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?.?.?"
    static let full = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?.?.?"
    static let gitSha = Bundle.main.infoDictionary?["ComYuvalShavitWtfdidVersion"] as? String ?? "???????"
    
    static var pretty : String {
        get {
            Bundle.main.infoDictionary?.forEach({(key, value) in
                print("\(key) => \(value)")
            })
            return "\(short) (\(full) @\(gitSha))"
        }
    }
}
