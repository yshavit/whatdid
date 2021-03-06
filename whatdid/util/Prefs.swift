// whatdid?

import Cocoa

struct Prefs {
    @Pref(key: "dailyReportTime") static var dailyReportTime = HoursAndMinutes(hours: 18, minutes: 00)
    @Pref(key: "dayStartTime") static var dayStartTime = HoursAndMinutes(hours: 09, minutes: 00)
    @Pref(key: "daysIncludeWeekends") static var daysIncludeWeekends = false
    @Pref(key: "ptnFrequencyMinutes") static var ptnFrequencyMinutes = 12
    @Pref(key: "ptnFrequencyJitterMinutes") static var ptnFrequencyJitterMinutes = 2
    @Pref(key: "launchAtLogin") static var launchAtLogin = false
    @Pref(key: "previouslyLaunchedVersion") static var tutorialVersion = -1
    @Pref(key: "requireNotes") static var requireNotes = false
}

@propertyWrapper
class Pref<T: PrefType> {
    private let key: String
    var projectedValue: PrefsListeners<T>
    
    init(wrappedValue: T, key: String) {
        self.key = "whatdid." + key
        UserDefaults.standard.register(defaults: [self.key: wrappedValue.asUserDefaultsValue])
        projectedValue = PrefsListeners(wrappedValue)
        projectedValue.notify(newValue: self.wrappedValue)
        #if UI_TEST
        allPrefs.append(self)
        #endif
    }
    
    var wrappedValue: T {
        get {
            return T.readUserDefaultsValue(key: key)
        }
        set(value) {
            T.writeUserDefaultsValue(key: key, value: value)
            projectedValue.notify(newValue: value)
        }
    }
}

class PrefsListeners<T> {
    private var currentValue: T
    private var listeners = [UUID: (T) -> Void]()
    
    init(_ defaultValue: T) {
        self.currentValue = defaultValue
    }
    
    @discardableResult
    func addListener(_ block: @escaping (T) -> Void) -> PrefsListenHandler {
        let handlerUuid = UUID()
        let handler = PrefsListenHandler() {
            self.listeners.removeValue(forKey: handlerUuid)
        }
        listeners[handlerUuid] = block
        block(currentValue)
        return handler
    }
    
    fileprivate func notify(newValue: T) {
        self.currentValue = newValue
        listeners.values.forEach { $0(newValue) }
    }
}

struct PrefsListenHandler {
    fileprivate let unregisterAction: () -> Void
    
    func unregister() {
        unregisterAction()
    }
}

protocol PrefType {
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

extension Int: PrefType {
    static func readUserDefaultsValue(key: String) -> Int {
        return UserDefaults.standard.integer(forKey: key)
    }
    
    static func writeUserDefaultsValue(key: String, value: Int) {
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
            wdlog(.error, "Invalid minutes for HoursAndMinutes: %d:%d. Assuming minutes=00", hours, minutes)
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
    
    func map<T>(_ function: (_ hh: Int, _ mm: Int) -> T) -> T {
        return function(hours, minutes)
    }
}

#if UI_TEST
private protocol ResettablePref {
    func resetPref()
}
private var allPrefs = [ResettablePref]()

func resetAllPrefs() {
    allPrefs.forEach { $0.resetPref() }
}

extension Pref: ResettablePref {
    
    func resetPref() {
        UserDefaults.standard.removeObject(forKey: self.key)
        let defaultValue = wrappedValue // we just deleted the old value, so this will read the default
        wrappedValue = defaultValue
    }
}
#endif
