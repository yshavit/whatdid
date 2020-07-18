import Cocoa

class Model {
    
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
    
    func addEntry(project: String, task: String, notes: String, now: Date, callback: @escaping (Error?)->()) {
        container.performBackgroundTask({context in
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            
            let projectData = Project.init(context: context)
            projectData.project = project
            projectData.lastUsed = now
            
            let taskData = Task.init(context: context)
            taskData.project = projectData
            taskData.task = task
            taskData.lastUsed = now
            
            let entry = Entry.init(context: context)
            entry.task = taskData
            entry.timeApproximatelyStarted = now // TODO
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
