// whatdid?
#if UI_TEST
import Cocoa
extension FlatEntry {
    
    static func deserialize(from json: String) -> [FlatEntry] {
        if json.trimmingCharacters(in: .whitespaces).isEmpty {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        if let jsonData = json.data(using: .utf8) {
            do {
                return try decoder.decode([FlatEntry].self, from: jsonData)
            } catch {
                NSLog("Error deserializing \(json): \(error)")
                return nil!
            }
        } else {
            NSLog("Couldn't get UTF-8 data from string: \(json)")
            return nil!
        }
    }
    
    static func serialize(_ entries: FlatEntry...) -> String {
        return serialize(entries)
    }
    
    static func serialize(_ entries: [FlatEntry]) -> String {
        if entries.isEmpty {
            return ""
        }
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .millisecondsSince1970
            let jsonData = try encoder.encode(entries)
            return String(data: jsonData, encoding: .utf8)!
        } catch {
            NSLog("failed to encode \(self): \(error)")
            return nil!
        }
    }
}
#endif
