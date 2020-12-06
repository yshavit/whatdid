// whatdid?

import Cocoa

class Version: NSObject {
    static let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?.?.?"
    static let full = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?.?.?"
    static let gitSha = Bundle.main.infoDictionary?["ComYuvalShavitWtfdidVersion"] as? String ?? "???????"
    static let copyright = Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String ?? "Copyright 2020 Yuval Shavit"
    
    static var pretty : String {
        get {
            return "v\(short) (\(full) @\(gitSha))"
        }
    }
}
