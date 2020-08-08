// whatdid?
#if UI_TEST
import Cocoa
extension Model {
    func clearAll() {
        getContainer().performBackgroundTask {context in
            do {
                var allObjects = [NSManagedObject]()
                for entityName in ["Project", "Task", "Entry"] {
                    let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
                    allObjects += try request.execute()
                }
                allObjects.forEach {context.delete($0)}
                try context.save()
            } catch {
                fatalError("couldn't delete all objects: \(error)")
            }
        }
    }
}
#endif

