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
    
    #if UI_TEST
    private var entriesListeners = [() -> Void]()
    
    convenience init(emptyCopyOf other: Model) {
        self.init(modelName: other.modelName, clearAllEntriesOnStartup: other.clearAllEntriesOnStartup)
        entriesListeners.append(contentsOf: other.entriesListeners)
        notifyListeners()
    }
    
    func addListener(_ listener: @escaping () -> Void) {
        entriesListeners.append(listener)
    }
    
    func notifyListeners() {
        DispatchQueue.main.async {
            self.entriesListeners.forEach { $0() }
        }
    }
    #endif
    
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
            wdlog(.info, "deleting all previous entries.")
            for store in localContainer.persistentStoreDescriptions {
                if let url = store.url {
                    do {
                        let urlFileName = url.lastPathComponent
                        let parentUrl = url.deletingLastPathComponent()
                        let siblingFiles = try FileManager.default.contentsOfDirectory(atPath: parentUrl.path)
                        let similarlyPrefixedFileUrls = siblingFiles.filter({ $0.hasPrefix(urlFileName) }).map(parentUrl.appendingPathComponent(_:))
                        for fileToDelete in similarlyPrefixedFileUrls {
                            wdlog(.info, "will delete %@", fileToDelete as NSURL)
                            try FileManager.default.removeItem(at: fileToDelete)
                        }
                    } catch {
                        wdlog(.error, "couldn't rm %@ and siblings: %@", url as NSURL, error as NSError)
                        fatalError("couldn't rm \(url) and siblings: \(error)")
                    }
                } else {
                    wdlog(.error, "No URL for store: %@", store.debugDescription)
                }
            }
        }
        localContainer.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }
        
        localContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        localContainer.viewContext.automaticallyMergesChangesFromParent = true
        return localContainer
    }()
    
    func setLastEntryDateToNow() {
        wdlog(.info, "Skipping session")
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
                wdlog(.error, "couldn't load projects: %@", error as NSError)
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
                wdlog(.error, "couldn't load projects: %@", error as NSError)
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
                wdlog(.error, "couldn't load projects: %@", error as NSError)
                results = []
            }
        }
        return results
    }
    
    func createNewSession() -> Session {
        var result: Session?
        container.viewContext.performAndWait {
            do {
                wdlog(.debug, "Creating new session")
                result = Session(context: container.viewContext)
                result?.startTime = DefaultScheduler.instance.now
                try container.viewContext.save()
            } catch {
                wdlog(.error, "couldn't save session: %@", error as NSError)
            }
        }
        return result!
    }
    
    func getCurrentSession() -> Session? {
        var result: Session?
        container.viewContext.performAndWait {
            do {
                let request = NSFetchRequest<Session>(entityName: "Session")
                request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
                request.fetchLimit = 1
                result = try request.execute().first
            } catch {
                wdlog(.error, "couldn't save session: %@", error as NSError)
            }
        }
        return result
    }
    
    func getOrCreateCurrentSession() -> Session {
        if let current = getCurrentSession() {
            return current
        } else {
            return createNewSession()
        }
    }
    
    func listGoalsForCurrentSession() -> [GoalDto] {
        var results = [GoalDto]()
        container.viewContext.performAndWait {
            results = getOrCreateCurrentSession().goals.map(GoalDto.fromManaged(_:))
        }
        results.sort()
        return results
    }
    
    func listGoals(since: Date) -> [GoalDto] {
        var results = [GoalDto]()
        container.viewContext.performAndWait {
            let request = NSFetchRequest<Goal>(entityName: "Goal")
            request.predicate = NSPredicate(format: "created >= %@", since as NSDate)
            do {
                results = try request.execute().map(GoalDto.fromManaged(_:))
            } catch {
                wdlog(.error, "couldn't lists goals since %@: %@", since as NSDate, error as NSError)
            }
        }
        results.sort()
        return results
    }
    
    func createNewGoal(goal text: String) -> GoalDto {
        var result: GoalDto?
        container.viewContext.performAndWait {
            do {
                let session = getOrCreateCurrentSession()
                let goal = Goal(context: container.viewContext)
                goal.created = DefaultScheduler.instance.now
                goal.during = session
                goal.goal = text
                goal.during = session
                goal.orderWithinSession = NSNumber(integerLiteral: session.goals.count)
                try container.viewContext.save()
                result = GoalDto.fromManaged(goal)
            } catch {
                wdlog(.error, "couldn't save goal: %@", error as NSError)
            }
        }
        return result!
    }
    
    func save(goal: GoalDto) {
        container.performBackgroundTask {context in
            guard let objectId = context.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: goal.id) else {
                wdlog(.error, "Error getting NSManagedObjectID for %@", goal.id as NSURL)
                return
            }
            let managedObj = context.object(with: objectId)
            guard let managed = managedObj as? Goal else {
                wdlog(.error, "object is not a Goal: %@", managedObj)
                return
            }
            managed.completed = goal.completed
            do {
                try context.save()
            } catch {
                wdlog(.error, "Error saving entry: %@", error as NSError)
            }
        }
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
                wdlog(
                    .debug,
                    "Saving %@ (%@)",
                    flatEntry.description,
                    TimeUtil.daysHoursMinutes(for: flatEntry.to.timeIntervalSince1970 - flatEntry.from.timeIntervalSince1970))
                try context.save()
            } catch {
                wdlog(.error, "Error saving entry: %@", error as NSError)
            }
            callback()
            #if UI_TEST
            self.notifyListeners()
            #endif
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
    
    struct GoalDto: Comparable {
        static func < (lhs: Model.GoalDto, rhs: Model.GoalDto) -> Bool {
            return lhs.created < rhs.created
                || lhs.orderWithinSession < rhs.orderWithinSession
                || lhs.goal < rhs.goal
        }
        
        fileprivate let id: URL
        let goal: String
        let created: Date
        var completed: Date?
        let sessionStart: Date
        fileprivate var orderWithinSession: Int
        
        fileprivate static func fromManaged(_ goal: Goal) -> GoalDto {
            return GoalDto(
                id: goal.objectID.uriRepresentation(),
                goal: goal.goal,
                created: goal.created,
                completed: goal.completed,
                sessionStart: goal.during?.startTime ?? goal.created,
                orderWithinSession: goal.orderWithinSession?.intValue ?? -1)
        }
        
        var isCompleted: Bool {
            completed != nil
        }
    }
}
