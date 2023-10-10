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
    @Pref(key: "startupMessages") static var startupMessages = [StartupMessage]()
    @Pref(key: "analyticsEnabled") static var analyticsEnabled = false
    @Pref(key: "analyticsTrackerId") static var trackerId = UUID()
    
    // The following aren't actually prefs, but rather just bits of info persisted across runs.
    @Pref(key: "scheduledOpens") static var scheduledOpens = [MainMenu.WindowContents:Date]()
    @Pref(key: "lastEntryDate") static var lastEntryEpoch = Double.nan
    
    #if canImport(Sparkle)
    @Pref(key: "updateChannels") static var updateChannels = Set<UpdateChannel>([])
    #endif
    
    #if UI_TEST
    private(set) static var raw = Prefs.createUserDefaults()
    static func resetRaw() {
        Prefs.raw = Prefs.createUserDefaults()
    }
    private static func createUserDefaults() -> UserDefaults {
        let suiteName = "com.yuvalshavit.whatdidUITests"
        let ud = UserDefaults(suiteName: suiteName)!
        ud.removePersistentDomain(forName: suiteName)
        return ud
    }
    #else
    static let raw = UserDefaults.standard;
    #endif
}

@propertyWrapper
class Pref<T: PrefType> {
    var projectedValue: PrefsListeners<T>
    
    init(wrappedValue: T, key: String) {
        let key = namespace + key
        Prefs.raw.register(defaults: [key: wrappedValue.asUserDefaultsValue])
        projectedValue = PrefsListeners(key, wrappedValue)
        projectedValue.notify(newValue: self.wrappedValue)
    }
    
    var wrappedValue: T {
        get {
            projectedValue.getValue()
        }
        set(value) {
            projectedValue.setValue(to: value)
        }
    }
}

class PrefsListeners<T: PrefType> {
    private let key: String
    private var currentValue: T
    private var listeners = [UUID: (T) -> Void]()
    
    init(_ key: String, _ defaultValue: T) {
        self.key = key
        self.currentValue = defaultValue
    }
    
    func getValue() -> T {
        return T.readUserDefaultsValue(key: key)
    }
    
    func setValue(to value: T) {
        T.writeUserDefaultsValue(key: key, value: value)
        notify(newValue: value)
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
        return Prefs.raw.bool(forKey: key)
    }
    
    static func writeUserDefaultsValue(key: String, value: Bool) {
        Prefs.raw.set(value, forKey: key)
    }
    
    var asUserDefaultsValue: Any {
        self
    }
}

extension Double: PrefType {
    static func readUserDefaultsValue(key: String) -> Double {
        Prefs.raw.double(forKey: key)
    }
    
    static func writeUserDefaultsValue(key: String, value: Double) {
        Prefs.raw.set(value, forKey: key)
    }
    
    var asUserDefaultsValue: Any {
        Double.nan
    }
}

extension Int: PrefType {
    static func readUserDefaultsValue(key: String) -> Int {
        return Prefs.raw.integer(forKey: key)
    }
    
    static func writeUserDefaultsValue(key: String, value: Int) {
        Prefs.raw.set(value, forKey: key)
    }
    
    var asUserDefaultsValue: Any {
        self
    }
}

extension Array: PrefType where Element == StartupMessage {
    static func readUserDefaultsValue(key: String) -> Array<Element> {
        guard let rawArray = Prefs.raw.array(forKey: key) else {
            wdlog(.info, "reading Prefs<[StartupMessage]>: not an array")
            return []
        }
        guard let asInts = rawArray as? [Int] else {
            wdlog(.info, "reading Prefs<[StartupMessage]>: not an int array")
            return []
        }
        return asInts.compactMap({StartupMessage(rawValue: $0)})
    }
    
    static func writeUserDefaultsValue(key: String, value: Array<Element>) {
        Prefs.raw.set(toNSArray(value), forKey: key)
    }
    
    var asUserDefaultsValue: Any {
        Array.toNSArray(self)
    }
    
    static func toNSArray(_ list: [StartupMessage]) -> NSArray {
        let unique = Set(list).compactMap({NSInteger($0.rawValue)})
        return NSArray(array: unique)
    }
}

extension Set: PrefType where Element == UpdateChannel {
    static func readUserDefaultsValue(key: String) -> Set<Element> {
        guard let rawArray = Prefs.raw.array(forKey: key) else {
            wdlog(.info, "reading Prefs<[StartupMessage]>: not an array")
            return []
        }
        guard let asStrings = rawArray as? [String] else {
            wdlog(.info, "reading Prefs<[StartupMessage]>: not an int array")
            return []
        }
        let asEnumValues = asStrings.compactMap( {UpdateChannel(rawValue: $0) })
        return Set(asEnumValues)
    }
    
    static func writeUserDefaultsValue(key: String, value: Set<Element>) {
        let asNsStrings = value.map({$0.rawValue})
        let arr = NSArray(array: asNsStrings)
        Prefs.raw.set(arr, forKey: key)
    }
    
    var asUserDefaultsValue: Any {
        NSArray(array: Array(self))
    }
}

extension Dictionary: PrefType where Key == MainMenu.WindowContents, Value == Date {
    static func readUserDefaultsValue(key: String) -> Dictionary<MainMenu.WindowContents, Date> {
        guard let rawDict = Prefs.raw.dictionary(forKey: key) else {
            wdlog(.info, "reading Prefs<[WindowContents: Date]>: not a dictionary")
            return [MainMenu.WindowContents:Date]()
        }
        let mappedPairs = rawDict.compactMap {(key: String, val: Any) -> (MainMenu.WindowContents, Date)? in
            if let keyInt = Int(key),
                  let keyWinContents = MainMenu.WindowContents(rawValue: keyInt),
                  let epoch = val as? TimeInterval
            {
                return (keyWinContents, Date(timeIntervalSince1970: epoch))
            } else {
                return nil
            }
        }
        return Dictionary(uniqueKeysWithValues: mappedPairs)
    }
    
    static func writeUserDefaultsValue(key: String, value: Dictionary<MainMenu.WindowContents, Date>) {
        let mappedPairs = value.map {(key, val) in
            (String(describing: key.rawValue), val.timeIntervalSince1970)
        }
        let mappedDict = Dictionary<String, TimeInterval>(uniqueKeysWithValues: mappedPairs)
        Prefs.raw.set(NSDictionary(dictionary: mappedDict), forKey: key)
    }
    
    var asUserDefaultsValue: Any {
        NSDictionary(dictionary: self)
    }
}

struct HoursAndMinutes: PrefType {
    static func readUserDefaultsValue(key: String) -> HoursAndMinutes {
        let encoded = Prefs.raw.integer(forKey: key)
        return HoursAndMinutes(encoded: encoded)
    }
    
    static func writeUserDefaultsValue(key: String, value: HoursAndMinutes) {
        Prefs.raw.set(value.encoded, forKey: key)
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

extension UUID: PrefType {
    
    static func readUserDefaultsValue(key: String) -> UUID {
        let s = Prefs.raw.string(forKey: key)
        if let s = s, let uuid = UUID(uuidString: s) {
            return uuid
        } else {
            return zero
        }
    }
    
    static func writeUserDefaultsValue(key: String, value: UUID) {
        Prefs.raw.set(value.uuidString, forKey: key)
    }
    
    var asUserDefaultsValue: Any {
        uuidString
    }
}

let namespace = "whatdid."
