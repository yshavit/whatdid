import Cocoa

class Model: NSPersistentContainer {

    func listProjects() -> [Project] {
        let request = NSFetchRequest<Project>(entityName: "Project")
        var result : [Project]!
        viewContext.performAndWait {
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
