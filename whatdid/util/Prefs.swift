// whatdid?

import Cocoa

struct Prefs {
    @Pref(key: "keyboardShortcutInitializedOnFirstStartup") static var keyboardShortcutInitializedOnFirstStartup = false
    @Pref(key: "dailyReportTime") static var dailyReportTime = HoursAndMinutes(hours: 18, minutes: 00)
}

@propertyWrapper
fileprivate struct Pref<T: PrefType> {
    private let key: String
    
    fileprivate init(wrappedValue: T, key: String) {
        self.key = key
        UserDefaults.standard.register(defaults: [key: wrappedValue.asUserDefaultsValue])
    }
    
    var wrappedValue: T {
        get {
            return T.readUserDefaultsValue(key: key)
        }
        set(value) {
            T.writeUserDefaultsValue(key: key, value: value)
        }
    }
}

fileprivate protocol PrefType {
    static func readUserDefaultsValue(key: String) -> Self
    static func writeUserDefaultsValue(key: String, value: Self)
    var asUserDefaultsValue: Any { get }
}

extension Bool: PrefType {
    static func readUserDefaultsValue(key: String) -> Bool {
        return UserDefaults.standard.bool(forKey: key)
    }
    
    static func writeUserDefaultsValue(key: String, value: Bool) {
        UserDefaults.standard.set(value, forKey: key)
    }
    
    var asUserDefaultsValue: Any {
        self
    }
}

struct HoursAndMinutes: PrefType {
    static func readUserDefaultsValue(key: String) -> HoursAndMinutes {
        let encoded = UserDefaults.standard.integer(forKey: key)
        return HoursAndMinutes(encoded: encoded)
    }
    
    static func writeUserDefaultsValue(key: String, value: HoursAndMinutes) {
        UserDefaults.standard.set(value.encoded, forKey: key)
    }
    
    var asUserDefaultsValue: Any {
        encoded
    }
    
    private let hours: Int
    private let minutes: Int
    
    init(hours: Int, minutes: Int) {
        self.hours = hours
        if minutes < 0 || minutes > 59 {
            NSLog("Invalid minutes for HoursAndMinutes: \(hours):\(minutes). Assuming minutes=00")
            self.minutes = 0
        } else {
            self.minutes = minutes
        }
    }
    
    init(encoded: Int) {
        self.init(
            hours: encoded / 100,
            minutes: (abs(encoded) % 100)
        )
    }
    
    var encoded: Int {
        var result = hours * 100
        if result < 0 {
            result -= minutes
        } else {
            result += minutes
        }
        return result
    }
    
    func read(_ block: (_ hh: Int, _ mm: Int) -> Void) {
        block(hours, minutes)
    }
}
