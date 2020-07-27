import Cocoa

class Version: NSObject {
    static let (major, minor, build) = Version.parseVersion()
    
    private static func parseVersion() -> (Int, Int, String) {
        if let versionString = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            let splits = versionString.split(separator: ".", maxSplits: 2, omittingEmptySubsequences: false)
            var major = "0"
            var minor = "0"
            var build : String?
            switch splits.count {
            case 3:
                build = String(splits[2])
                fallthrough
            case 2:
                minor = String(splits[1])
                fallthrough
            case 1:
                major = String(splits[0])
            default:
                NSLog("Unexpectedly found more than 3 splits from %@: %@", versionString, splits)
            }
            // The build number has to be a decimal digit, but it's actually an 8-digit hex.
            var buildPretty : String
            if let buildStr = build {
                if var buildNum = UInt64(buildStr) {
                    // A suffix of 0xffff means the build was git space was dirty
                    // See buildscripts/set_plist_build.sh
                    let gitDirtyMarker : String
                    if buildNum & 0xffff == 0xffff {
                        buildNum >>= 16
                        gitDirtyMarker = "-dirty"
                    } else {
                        gitDirtyMarker = ""
                    }
                    buildPretty = String(format: "%x%@", buildNum, gitDirtyMarker)
                } else {
                    buildPretty = "x"
                }
            } else {
                buildPretty = "0"
            }
            return (tryParse(major), tryParse(minor), buildPretty)
        } else {
            return (-1, -1, "x")
        }
    }
    
    static var pretty : String {
        get {
            return "\(major).\(minor).\(build)"
        }
    }
    
    private static func tryParse(_ string: String) -> Int {
        if let parsed = Int(string) {
            return parsed
        } else {
            NSLog("Couldn't parse string: %@", string)
            return -1
        }
    }
}
