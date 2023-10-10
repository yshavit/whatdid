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
        #elseif DEBUG
        self.init(modelName: "DebugModel")
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
        let lastEntryEpoch = Prefs.lastEntryEpoch
        if lastEntryEpoch.isFinite {
            _lastEntryDate = Date(timeIntervalSince1970: lastEntryEpoch)
        } else {
            let now = DefaultScheduler.instance.now
            _lastEntryDate = now
            setLastEntryDate(to: now)
        }
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
    
    private func setLastEntryDate(to date: Date) {
        _lastEntryDate = date
        Prefs.lastEntryEpoch = date.timeIntervalSince1970
    }
    
    func setLastEntryDateToNow() {
        wdlog(.info, "Skipping session")
        setLastEntryDate(to: DefaultScheduler.instance.now)
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
                tasks = try request.execute()
            } catch {
                wdlog(.error, "couldn't load projects: %@", error as NSError)
                tasks = []
            }
            results = tasks.map({$0.task})
            
        }
        return results
    }

    func rewrite(entries toWrite: [RewrittenFlatEntry], andThen callback: @escaping (Bool) -> Void) {
        let callback = {(success: Bool) in
            DispatchQueue.main.async { callback(success) }
        }
        // Get all of the old projects, and for each one its tasks. We'll use this to clean up any dangling
        // projects or tasks at the end.
        var originalProjectsAndTasks = [String:Set<String>]()
        for rewrite in toWrite {
            let original = rewrite.original.entry
            var tasks = originalProjectsAndTasks[original.project] ?? Set()
            tasks.insert(original.task)
            originalProjectsAndTasks[original.project] = tasks
        }

        // Get the new projects and tasks, and for each one, calculate its last-used date. We'll use this to update
        // the projects' and tasks' `lastUsed` below
        var newProjectsAndTasks = [String:[String:Date]]()
        for rewrite in toWrite {
            let project = rewrite.newValue.project.trimmingCharacters(in: .whitespacesAndNewlines)
            let task = rewrite.newValue.task.trimmingCharacters(in: .whitespacesAndNewlines)
            let newDate = rewrite.newValue.to
            var tasks = newProjectsAndTasks[project] ?? [:]
            if newDate > (tasks[task] ?? Date.distantPast) {
                tasks[task] = newDate
            }
            newProjectsAndTasks[project] = tasks
        }

        // Prep work is done, let's go!
        container.performBackgroundTask {context in
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

            // A couple utils, for finding existing projects and tasks
            func fetch(project: String) throws -> Project? {
                let projectRequest = Project.fetchRequest()
                projectRequest.predicate = NSPredicate(format: "%K = %@", #keyPath(Project.project), project)
                projectRequest.fetchLimit = 1
                return try projectRequest.execute().first
            }

            func fetch(task: String, within project: Project) throws -> Task? {
                let taskRequest = Task.fetchRequest()
                taskRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSPredicate(format: "%K = %@", #keyPath(Task.project), project),
                    NSPredicate(format: "%K = %@", #keyPath(Task.task), task),
                ])
                taskRequest.fetchLimit = 1
                return try taskRequest.execute().first
            }

            // First step: make sure all the new projects and tasks are there, and with an up-to-date `lastUpdated`.
            // If any are missing, create them
            var tasksByPat = [ProjectAndTask: Task]()
            do {
                for (project, tasksAndDate) in newProjectsAndTasks {
                    let projectObj: Project
                    if let existingProjectObj = try fetch(project: project) {
                        projectObj = existingProjectObj
                    } else {
                        projectObj = Project(context: context)
                        projectObj.project = project
                        projectObj.lastUsed = Date.distantPast
                    }
                    for (task, lastUsedInRewrittens) in tasksAndDate {
                        let taskObj: Task
                        if let existingTaskObj = try fetch(task: task, within: projectObj) {
                            taskObj = existingTaskObj
                        } else {
                            taskObj = Task(context: context)
                            taskObj.project = projectObj
                            taskObj.task = task
                            taskObj.lastUsed = Date.distantPast
                        }
                        taskObj.lastUsed = max(taskObj.lastUsed, lastUsedInRewrittens)
                        tasksByPat[ProjectAndTask(project: project, task: task)] = taskObj
                    }
                }
            } catch {
                wdlog(.error, "Failed to fetch existing projects and tasks: %@", error as NSError)
                callback(false)
                return
            }

            // Next, write the new entries. For each one, we expect there to be a pre-existing entry. So we're not
            // actually writing any new entries; rather, we're looking up the old ones and editing them.
            for rewrite in toWrite {
                let newEntry = rewrite.newValue
                guard let fetched = context.object(with: rewrite.original.objectId) as? Entry else {
                    wdlog(.error, "couldn't fetch Entry with id=%@", rewrite.original.objectId)
                    continue
                }
                guard let taskObj = tasksByPat[ProjectAndTask(project: newEntry.project, task: newEntry.task)] else {
                    wdlog(.error, "couldn't fetch project and task: (%@, %@)", newEntry.project, newEntry.task)
                    continue
                }
                fetched.notes = newEntry.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
                fetched.task = taskObj
            }

            // Finally, cleanup: Look through all of the old projects and tasks. For each one, see if it has any
            // children, and if not, delete it.
            // Note that if an old project or task should now have a newer lastUpdated, we *don't* modify that.
            // Mostly, this is out of laziness. :-) But it also makes some UX sense, I think: the user will remember
            // typing them recently, and so might expect them to show up in the autocompletes. Anyway, it'll all fade
            // away with use, so it doesn't matter much.
            do {
                for (project, tasks) in originalProjectsAndTasks {
                    guard let projectObj = try fetch(project: project) else {
                        continue
                    }
                    for task in tasks {
                        guard let taskObj = try fetch(task: task, within: projectObj) else {
                            continue
                        }
                        if taskObj.entries.isEmpty {
                            context.delete(taskObj)
                            projectObj.tasks.remove(taskObj)
                            wdlog(.info, "deleting now-unused task: %@ > %@", project, task)
                        }
                    }
                    if projectObj.tasks.isEmpty {
                        context.delete(projectObj)
                        wdlog(.info, "deleting now-unused project: %@", project)
                    }
                }
            } catch {
                wdlog(.warn, "couldn't clean up projects or tasks: %@", error as NSError)
            }

            // Now just commit all of that, and report back
            var success = false
            do {
                wdlog(.debug, "rewriting flat entries: %d", toWrite.count)
                try context.save()
                success = true
            } catch {
                wdlog(.error, "Error saving entry: %@", error as NSError)
                success = false
            }
            callback(success)
            #if UI_TEST
            self.notifyListeners()
            #endif
        }
    }

    func listEntries(from: Date, to: Date) -> [FlatEntry] {
        listEntriesWithIds(from: from, to: to).map({$0.entry})
    }

    func listEntriesWithIds(from: Date, to: Date) -> [RewriteableFlatEntry] {
        var results : [RewriteableFlatEntry] = []
        container.viewContext.performAndWait {
            do {
                let request = NSFetchRequest<Entry>(entityName: "Entry")
                request.predicate = NSPredicate(
                    format: "(timeApproximatelyStarted >= %@) AND (timeApproximatelyStarted <= %@)",
                    from as NSDate,
                    to as NSDate)
                request.sortDescriptors = [.init(key: "timeApproximatelyStarted", ascending: true)]
                let entries = try request.execute()
                results = entries.map({ entry in
                    RewriteableFlatEntry(
                            entry: FlatEntry(
                                    from: entry.timeApproximatelyStarted,
                                    to: entry.timeEntered,
                                    project: entry.task.project.project.trimmingCharacters(in: .controlCharacters),
                                    task: entry.task.task,
                                    notes: entry.notes),
                            objectId: entry.objectID)
                })
            } catch {
                wdlog(.error, "couldn't load projects: %@", error as NSError)
                results = []
            }
        }
        return results
    }
    
    func createUsage(action: UsageAction, andThen handler: @escaping (UsageDatumDTO) -> Void) {
        container.performBackgroundTask({context in
            let datum = UsageDatum(context: context)
            datum.trackerId = Prefs.trackerId
            datum.action = action.rawValue
            datum.timestamp = DefaultScheduler.instance.now
            datum.datumId = UUID()
            
            do {
                try context.save()
            } catch {
                wdlog(.error, "Couldn't save analytics tracking datum: %s %s at %s",
                      datum.trackerId?.uuidString ?? "<unset>",
                      datum.action ?? "<unknown action>",
                      datum.timestamp?.utcTimestamp ?? "<unset date>"
                )
                return
            }
            guard let dto = UsageDatumDTO(from: datum) else {
                wdlog(.error, "couldn't construct usage DTO")
                return
            }
            DispatchQueue.global(qos: .background).async {
                handler(dto)
            }
        })
    }
    
    func recordAnalyticSubmitted(_ datum: UsageDatumDTO) {
        container.performBackgroundTask{context in
            func id(for a: UsageDatum) -> String {
                a.datumId?.uuidString ?? "<unknown>"
            }
            if let latest = context.object(with: datum.objectID) as? UsageDatum {
                if latest.sendSuccess == nil {
                    latest.sendSuccess = DefaultScheduler.instance.now
                    do {
                        try context.save()
                        wdlog(.info, "usage datum recorded: %@", id(for: latest))
                    } catch {
                        wdlog(.error, "couldn't save usage datum to record its send success: %@", id(for: latest))
                    }
                } else {
                    wdlog(.warn, "usage datum has already been marked as submitted: %@", id(for: latest))
                }
            } else {
                wdlog(.error, "couldn't re-fetch analytic datum to mark it as submitted: %@", datum.datumId.uuidString)
            }
        }
    }
    
    func getUnsentUsages(andThen handler: @escaping ([UsageDatumDTO]) -> Void) {
        container.performBackgroundTask {context in
            let fetch = NSFetchRequest<UsageDatum>(entityName: "UsageDatum")
            fetch.fetchLimit = 2
            fetch.predicate = NSPredicate(format: "%K == nil", "sendSuccess")
            let data: [UsageDatum]
            do {
                data = try fetch.execute()
            } catch {
                wdlog(.error, "couldn't fetch unsent usage data")
                return
            }
            let dtos = data.compactMap(UsageDatumDTO.init(from:))
            DispatchQueue.global(qos: .background).async {
                handler(dtos)
            }
        }
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
    
    func listGoals(from: Date, to: Date) -> [GoalDto] {
        var results = [GoalDto]()
        container.viewContext.performAndWait {
            let request = NSFetchRequest<Goal>(entityName: "Goal")
            request.predicate = NSPredicate(
                format: "(created >= %@) AND (created <= %@)",
                from as NSDate,
                to as NSDate)
            do {
                results = try request.execute().map(GoalDto.fromManaged(_:))
            } catch {
                wdlog(.error,
                      "couldn't lists goals from %{public}@ to %{public}@: %@",
                      from as NSDate,
                      to as NSDate,
                      error as NSError)
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
        setLastEntryDate(to: now)
        add(FlatEntry(from: lastUpdate, to: now, project: project, task: task, notes: notes), andThen: callback)
    }
    
    func add(_ flatEntry: FlatEntry, andThen callback: @escaping () -> ()) {
        container.performBackgroundTask({context in
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            
            let projectData = Project(context: context)
            projectData.project = flatEntry.project.trimmingCharacters(in: .whitespacesAndNewlines)
            projectData.lastUsed = flatEntry.to
            
            let taskData = Task(context: context)
            taskData.project = projectData
            taskData.task = flatEntry.task.trimmingCharacters(in: .whitespacesAndNewlines)
            taskData.lastUsed = flatEntry.to

            let entry = Entry(context: context)
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
        
        func forEach(_ block: (GroupedProject) throws -> Void) rethrows {
            try groupedProjects.values.map { ($0.totalTime, $0) }.sorted(by: { $0.0 > $1.0 }).map { $0.1 }.forEach(block)
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
        
        func forEach(_ block: (GroupedTask) throws -> Void) rethrows {
            // first sort in descending totalTime order
            try groupedTasks.values.map { ($0.totalTime, $0) } . sorted(by: { $0.0 > $1.0 }) . map { $0.1 } . forEach(block)
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
        
        func forEach(_ block: (FlatEntry) throws -> Void) rethrows {
            try entries.sorted(by: {$0.from < $1.from}).forEach(block)
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
        
        let id: URL
        let goal: String
        let created: Date
        var completed: Date?
        let sessionStart: Date
        let orderWithinSession: Int
        
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

enum UsageAction: String {
    case ManualOpen;
}
