import Cocoa

class Model {
    
    private let lastEntryDateDispatch = DispatchQueue(label: "com.yuvalshavit.wtfdid.model.var", qos: .default)
    private var _lastEntryDate = Date()
    
    init() {
        lastEntryDate = Date()
    }
    
    private lazy var container: NSPersistentContainer = {
        let localContainer = NSPersistentContainer(name: "Model")
        localContainer.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }
        localContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return localContainer
    }()
    
    var lastEntryDate : Date {
        get {
            return lastEntryDateDispatch.sync(execute: {
                print("getting lastEntryDate = \(self._lastEntryDate)")
                return self._lastEntryDate
            })
        }
        set(date) {
            lastEntryDateDispatch.async(execute: {
                self._lastEntryDate = date
                print("setting lastEntryDate to \(date)")
            })
        }
    }

    func listProjects() -> [Project] {
        var result : [Project]!
        container.viewContext.performAndWait {
            let request = NSFetchRequest<Project>(entityName: "Project")
            do {
                result = try request.execute()
            } catch {
                print("couldn't load projects: \(error)")
                result = []
            }
        }
        return result
    }
    
    func printAll() {
        container.viewContext.performAndWait {
            do {
                let projectsRequest = NSFetchRequest<Project>(entityName: "Project")
                let projects = try projectsRequest.execute()
                for project in projects {
                    print("\(project.project) (\(project.lastUsed))")
                    for task in project.tasks {
                        print("    \(task.task) (\(task.lastUsed))")
                        for entry in task.entries {
                            print("        \(entry.notes ?? "<no notes>"): from \(entry.timeApproximatelyStarted) to \(entry.timeEntered)")
                        }
                    }
                }
                print("")
            } catch {
                print("couldn't list everything: \(error)")
            }
            
        }
    }
    
    func addEntryNow(project: String, task: String, notes: String, callback: @escaping (Error?)->()) {
        container.performBackgroundTask({context in
            let lastUpdate = self.lastEntryDate
            let now = Date()
            self.lastEntryDate = now
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            
            let projectData = Project.init(context: context)
            projectData.project = project
            projectData.lastUsed = lastUpdate
            
            let taskData = Task.init(context: context)
            taskData.project = projectData
            taskData.task = task
            taskData.lastUsed = now
            
            let entry = Entry.init(context: context)
            entry.task = taskData
            entry.timeApproximatelyStarted = lastUpdate
            entry.timeEntered = now
            entry.notes = notes
            
            var maybeError : Error?
            do {
                try context.save()
                maybeError = nil
            } catch {
                print("error saving entry: \(error)")
                maybeError = error
            }
            callback(maybeError)
        })
    }
}
