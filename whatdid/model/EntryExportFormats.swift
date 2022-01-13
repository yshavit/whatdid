// whatdid?

import Cocoa
import Foundation
import SwiftUI

protocol EntryExportFormat {
    var name: String { get }
    var fileExtension: String { get }
    func write(entries: [FlatEntry], to out: OutputStream) throws
}

let allEntryExportFormats: [EntryExportFormat] = [
    TextTreeEntryExportFormat(),
    JsonEntryExportFormat(),
    CsvEntryExportFormat(),
]

class JsonEntryExportFormat : EntryExportFormat {
    
    let name = "json"
    let fileExtension = "json"
    
    func write(entries flatEntries: [FlatEntry], to out: OutputStream) throws {
        let projects = Model.GroupedProjects(from: flatEntries)
        var projectByName = [String: Project]()
        projects.forEach {project in
            var tasksByName = [String: Task]()
            project.forEach {task in
                var entries = [Entry]()
                task.forEach { e in
                    entries.append(Entry(from: e.from, to: e.to, notes: e.notes ?? ""))
                }
                tasksByName[task.name] = entries
            }
            projectByName[project.name] = tasksByName
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(projectByName)
        try out.write(jsonData)
    }
    
    private typealias Project = [String: Task]
    
    private typealias Task = [Entry]
    
    private struct Entry: Codable {
        let from : Date
        let to : Date
        let notes : String
    }
}

class TextTreeEntryExportFormat : EntryExportFormat {
    
    let name = "text"
    let fileExtension = "txt"
    
    func write(entries flatEntries: [FlatEntry], to out: OutputStream) throws {
        let projects = Model.GroupedProjects(from: flatEntries)
        let totalTime = projects.totalTime
        try out.write("Total time: ")
        try out.write(TimeUtil.daysHoursMinutes(for: totalTime))
        try out.write(newlineUtfData)
        
        func write(item: String, timeSpent: TimeInterval, indentBy indent: Int) throws {
            try out.write(String(repeating: " ", count: indent * 4))
            try out.write(String(
                format: "%.1f%% (%@): %@\n",
                (timeSpent / totalTime) * 100.0,
                TimeUtil.daysHoursMinutes(for: timeSpent), item))
        }
        
        try projects.forEach {project in
            try write(item: project.name, timeSpent: project.totalTime, indentBy: 1)
            try project.forEach {task in
                try write(item: task.name, timeSpent: task.totalTime, indentBy: 2)
                try task.forEach { entry in
                    var notes = entry.notes ?? ""
                    if notes.isEmpty {
                        notes = "(no notes entered)"
                    }
                    try write(item: notes, timeSpent: entry.duration, indentBy: 3)
                }
            }
        }
    }
}

class CsvEntryExportFormat : EntryExportFormat {
    var name = "csv"
    
    var fileExtension = "csv"
    
    func write(entries: [FlatEntry], to out: OutputStream) throws {
        guard let comma = ",".data(using: .utf8) else {
            throw OutputStream.OutputStreamError.stringConversionFailure
        }
        func field(_ string: String?, withDelimiter delimiter: Data = comma) throws {
            let string = string ?? ""
            if !string.isEmpty {
                let quoted = "\"" + string.replacingOccurrences(of: "\"", with: "\"\"") + "\""
                try out.write(quoted)
            }
            try out.write(delimiter)
        }
        
        try out.write("start_time,end_time,project,task,notes\n")
        
        let dateFormatter = ISO8601DateFormatter()
        try entries.sorted(by: {$0.from < $1.from && $0.to < $1.to}).forEach {entry in
            try field(dateFormatter.string(from: entry.from))
            try field(dateFormatter.string(from: entry.to))
            try field(entry.project)
            try field(entry.task)
            try field(entry.notes, withDelimiter: newlineUtfData)
        }
    }
    
}
