// wtfdid?

import Cocoa

class Version: NSObject {
    static let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?.?.?"
    static let full = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?.?.?"
    static let gitSha = Bundle.main.infoDictionary?["ComYuvalShavitWtfdidVersion"] as? String ?? "???????"
    
    static var pretty : String {
        get {
            return "\(short) (v\(full)@\(gitSha))"
        }
    }
}
