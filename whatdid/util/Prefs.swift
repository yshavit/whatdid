// whatdid?

import Cocoa

struct Prefs {
    @Pref(key: "keyboardShortcutInitializedOnFirstStartup") static var keyboardShortcutInitializedOnFirstStartup = false
}

@propertyWrapper
fileprivate struct Pref<T: PrefType> {
    private let key: String
    
    fileprivate init(wrappedValue: T, key: String) {
        self.key = key
        UserDefaults.standard.register(defaults: [key: wrappedValue])
    }
    
    var wrappedValue: T {
        get {
            return T.readPref(key: key)
        }
        set(value) {
            T.writePref(key: key, value: value)
        }
    }
}

fileprivate protocol PrefType {
    static func readPref(key: String) -> Self
    static func writePref(key: String, value: Self)
}

extension Bool: PrefType {
    static func readPref(key: String) -> Bool {
        return UserDefaults.standard.bool(forKey: key)
    }
    
    static func writePref(key: String, value: Bool) {
        UserDefaults.standard.set(value, forKey: key)
    }
}
