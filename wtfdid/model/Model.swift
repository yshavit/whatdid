import Cocoa

class Model {
    
    public static let instance = Model()
    
    private lazy var container: NSPersistentContainer = {
        let localContainer = NSPersistentContainer(name: "Model")
        localContainer.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }
        return localContainer
    }()

    func listProjects() -> [Project] {
        let request = NSFetchRequest<Project>(entityName: "Project")
        var result : [Project]!
        container.viewContext.performAndWait {
            do {
                result = try request.execute()
            } catch {
                print("couldn't load projects")
                result = []
            }
        }
        return result
    }
}
