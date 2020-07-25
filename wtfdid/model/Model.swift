import Cocoa

class Model {
    
    @Atomic private var lastEntryDate : Date
    
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
    
    func listProjects(prefix: String) -> [String] {
        var results : [String]!
        container.viewContext.performAndWait {
            let request = NSFetchRequest<Project>(entityName: "Project")
            
            let projects : [Project]
            do {
                request.sortDescriptors = [
                    .init(key: "lastUsed", ascending: false),
                    .init(key: "project", ascending: true)
                ]
                if !prefix.isEmpty {
                    request.predicate = NSPredicate(format: "project BEGINSWITH %@", prefix)
                }
                request.fetchLimit = 10
                projects = try request.execute()
            } catch {
                print("couldn't load projects: \(error)")
                projects = []
            }
            results = projects.map({$0.project})
            
        }
        return results
    }
    
    func listTasks(project: String, prefix: String) -> [String] {
        var results : [String]!
        container.viewContext.performAndWait {
            let request = NSFetchRequest<Task>(entityName: "Task")
            
            let tasks : [Task]
            do {
                request.sortDescriptors = [
                    .init(key: "lastUsed", ascending: false),
                    .init(key: "task", ascending: true)
                ]
                var predicate = NSPredicate(format: "project.project = %@", project)
                if !prefix.isEmpty {
                    predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                        predicate,
                        NSPredicate(format: "task BEGINSWITH %@", prefix)])
                }
                request.predicate = predicate
                request.fetchLimit = 10
                tasks = try request.execute()
            } catch {
                print("couldn't load projects: \(error)")
                tasks = []
            }
            results = tasks.map({$0.task})
            
        }
        return results
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
    
    func addEntryNow(project: String, task: String, notes: String, callback: @escaping ()->()) {
        container.performBackgroundTask({context in
            let lastUpdate = self.lastEntryDate
            let now = Date()
            self.lastEntryDate = now
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            
            let projectData = Project.init(context: context)
            projectData.project = project.trimmingCharacters(in: .whitespacesAndNewlines)
            projectData.lastUsed = lastUpdate
            
            let taskData = Task.init(context: context)
            taskData.project = projectData
            taskData.task = task.trimmingCharacters(in: .whitespacesAndNewlines)
            taskData.lastUsed = now
            
            let entry = Entry.init(context: context)
            entry.task = taskData
            entry.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.timeApproximatelyStarted = lastUpdate
            entry.timeEntered = now
            
            do {
                try context.save()
            } catch {
                print("error saving entry: \(error)")
            }
            callback()
        })
    }
}
