// whatdid?
#if UI_TEST
import Cocoa
import os

// NOTE: This file gets compiled both in main whatdid and whatdidUITests.
// The latter doesn't have access to `wdlog`, so we can't use that here.

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
                os_log(.error, "Error deserializing %@: %@", json, error as NSError)
                return []
            }
        } else {
            os_log(.error, "Couldn't get UTF-8 data from string: %@", json)
            return []
        }
    }
    
    static func serialize(_ nodes: FlatEntry...) -> String {
        return serialize(nodes)
    }
    
    static func serialize(_ nodes: [FlatEntry]) -> String {
        if nodes.isEmpty {
            return ""
        }
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .millisecondsSince1970
            let jsonData = try encoder.encode(nodes)
            return String(data: jsonData, encoding: .utf8)!
        } catch {
            os_log(.error, "failed to encode entries: %@", String(describing: nodes), error as NSError)
            return ""
        }
    }
}
#endif
