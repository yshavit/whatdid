// whatdid?

import Cocoa

class Model {
    
    private static let BREAK_PROJECT = "break"
    private static let BREAK_TASK = "break"
    private static let BREAK_TASK_NOTES = ""
    
    @Atomic private var _lastEntryDate : Date
    private let modelName: String
    private let clearAllEntriesOnStartup: Bool
    
    convenience init() {
        #if UI_TEST
        self.init(modelName: "UITest", clearAllEntriesOnStartup: true)
        #else
        self.init(modelName: "Model")
        #endif
    }
    
    init(modelName: String, clearAllEntriesOnStartup: Bool = false) {
        self.modelName = modelName
        self.clearAllEntriesOnStartup = clearAllEntriesOnStartup
        _lastEntryDate = DefaultScheduler.instance.now
    }
    
    private lazy var container: NSPersistentContainer = {
        guard let modelURL = Bundle.main.url(forResource: "Model", withExtension: "momd") else {
            fatalError("Failed to find data model")
        }
        guard let mom = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Failed to create model from file: \(modelURL)")
        }
        let localContainer = NSPersistentContainer(name: modelName, managedObjectModel: mom)
        if clearAllEntriesOnStartup {
            NSLog("deleting all previous entries.")
            for store in localContainer.persistentStoreDescriptions {
                if let url = store.url {
                    if FileManager.default.fileExists(atPath: url.path) {
                        NSLog("  rm \(url)")
                        do {
                            try FileManager.default.removeItem(at: url)
                        } catch {
                            fatalError("couldn't rm \(url): \(error)")
                        }
                    } else {
                        NSLog("  file does not exist: \(url)")
                    }
                } else {
                    NSLog("No URL for store: \(store.debugDescription)")
                }
            }
        }
        localContainer.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }
        
        localContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return localContainer
    }()
    
    func setLastEntryDateToNow() {
        _lastEntryDate = DefaultScheduler.instance.now
    }
    
    var lastEntryDate: Date {
        return _lastEntryDate
    }
    
    func listProjects() -> [String] {
        var results : [String]!
        container.viewContext.performAndWait {
            let request = NSFetchRequest<Project>(entityName: "Project")
            
            let projects : [Project]
            do {
                request.sortDescriptors = [
                    .init(key: "lastUsed", ascending: false),
                    .init(key: "project", ascending: true)
                ]
                request.fetchLimit = 10
                projects = try request.execute()
            } catch {
                NSLog("couldn't load projects: %@", error as NSError)
                projects = []
            }
            results = projects.map({$0.project})
            
        }
        return results
    }
    
    func listTasks(project: String) -> [String] {
        var results : [String]!
        container.viewContext.performAndWait {
            let request = NSFetchRequest<Task>(entityName: "Task")
            
            let tasks : [Task]
            do {
                request.sortDescriptors = [
                    .init(key: "lastUsed", ascending: false),
                    .init(key: "task", ascending: true)
                ]
                request.predicate = NSPredicate(format: "project.project = %@", project)
                request.fetchLimit = 10
                tasks = try request.execute()
            } catch {
                NSLog("couldn't load projects: %@", error as NSError)
                tasks = []
            }
            results = tasks.map({$0.task})
            
        }
        return results
    }
    
    func listEntries(since: Date) -> [FlatEntry] {
        var results : [FlatEntry] = []
        container.viewContext.performAndWait {
            do {
                let request = NSFetchRequest<Entry>(entityName: "Entry")
                request.predicate = NSPredicate(format: "timeApproximatelyStarted >= %@", since as NSDate)
                let entries = try request.execute()
                results = entries.map({entry in
                    FlatEntry(
                        from: entry.timeApproximatelyStarted,
                        to: entry.timeEntered,
                        project: entry.task.project.project.trimmingCharacters(in: .controlCharacters),
                        task: entry.task.task,
                        notes: entry.notes
                    )
                })
            } catch {
                NSLog("couldn't load projects: %@", error as NSError)
                results = []
            }
        }
        return results
    }
    
    func addEntryNow(project: String, task: String, notes: String, callback: @escaping ()->()) {
        let lastUpdate = self._lastEntryDate
        let now = DefaultScheduler.instance.now
        _lastEntryDate = now
        add(FlatEntry(from: lastUpdate, to: now, project: project, task: task, notes: notes), andThen: callback)
    }
    
    func add(_ flatEntry: FlatEntry, andThen callback: @escaping () -> ()) {
        container.performBackgroundTask({context in
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            
            let projectData = Project.init(context: context)
            projectData.project = flatEntry.project.trimmingCharacters(in: .whitespacesAndNewlines)
            projectData.lastUsed = flatEntry.to
            
            let taskData = Task.init(context: context)
            taskData.project = projectData
            taskData.task = flatEntry.task.trimmingCharacters(in: .whitespacesAndNewlines)
            taskData.lastUsed = flatEntry.to
            
            let entry = Entry.init(context: context)
            entry.task = taskData
            entry.notes = flatEntry.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.timeApproximatelyStarted = flatEntry.from
            entry.timeEntered = flatEntry.to
            
            do {
                NSLog(
                    "Saving %@ (%@)",
                    flatEntry.description,
                    TimeUtil.daysHoursMinutes(for: flatEntry.to.timeIntervalSince1970 - flatEntry.from.timeIntervalSince1970))
                try context.save()
            } catch {
                NSLog("Error saving entry: %@", error as NSError)
            }
            callback()
        })
    }
    
    #if UI_TEST
    func getContainer() -> NSPersistentContainer {
        return container
    }
    #endif
    
    class GroupedProjects {
        var groupedProjects = [String: GroupedProject]()
        
        init(from entries: [FlatEntry]) {
            entries.forEach {entry in add(flatEntry: entry) }
        }
        
        final func add(flatEntry entry: FlatEntry) {
            var project = groupedProjects[entry.project]
            if project == nil {
                project = GroupedProject(name: entry.project)
                groupedProjects[entry.project] = project
            }
            project?.add(flatEntry: entry)
        }
        
        func forEach(_ block: (GroupedProject) -> Void) {
            groupedProjects.values.map { ($0.totalTime, $0) }.sorted(by: { $0.0 > $1.0 }).map { $0.1 }.forEach(block)
        }
        
        var totalTime: TimeInterval {
            get {
                return groupedProjects.values.compactMap { $0.totalTime }.reduce(0, +)
            }
        }
    }
    
    class GroupedProject {
        let name: String;
        private var groupedTasks = [String: GroupedTask]()
        
        init(name: String) {
            self.name = name
        }
        
        func add(flatEntry entry: FlatEntry) {
            var task = groupedTasks[entry.task]
            if task == nil {
                task = GroupedTask(name: entry.task)
                groupedTasks[entry.task] = task
            }
            task!.add(flatEntry: entry)
        }
        
        func forEach(_ block: (GroupedTask) -> Void) {
            // first sort in descending totalTime order
            groupedTasks.values.map { ($0.totalTime, $0) } . sorted(by: { $0.0 > $1.0 }) . map { $0.1 } . forEach(block)
        }
        
        var totalTime: TimeInterval {
            get {
                return groupedTasks.values.compactMap { $0.totalTime }.reduce(0, +)
            }
        }
    }
    
    class GroupedTask {
        let name: String
        private var entries = [FlatEntry]()
        
        init(name: String) {
            self.name = name
        }
        
        func add(flatEntry entry: FlatEntry) {
            entries.append(entry)
        }
        
        func forEach(_ block: (FlatEntry) -> Void) {
            entries.sorted(by: {$0.from < $1.from}).forEach(block)
        }
        
        var totalTime: TimeInterval {
            get {
                return entries.compactMap { $0.duration }.reduce(0, +)
            }
        }
    }
}
