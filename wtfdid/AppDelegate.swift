import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBOutlet weak var systemMenu: MainMenu!
    
    lazy var persistentContainer: Model = {
        let container = Model(name: "Model")
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }
        return container
    }()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Our Info.plist starts us off as background. Now that we're started, become an accessory app.
        // This approach lets us start the app deactivated.
        NSApp.setActivationPolicy(.accessory)
        
        dataTest()
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        systemMenu.open()
    }
    
    func applicationDidResignActive(_ notification: Notification) {
        systemMenu.hideItem()
    }
    
    func dataTest() {
        print("running data test")
        
        do {
            let projects = persistentContainer.listProjects()
            print("got projects. count = \(projects.count)")
            for p in projects {
                print("project: \(p.project)")
            }
            
            let context = persistentContainer.viewContext
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            let p = Project.init(context: context)
            p.project = "my project"
            print("object id before save: \(p.objectID)")
            try context.save()
            print("object id after save:  \(p.objectID)")
            
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
        }
    }

}

