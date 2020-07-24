import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    public static let instance = NSApplication.shared.delegate as! AppDelegate
    
    public let model = Model()
    @IBOutlet private weak var systemMenu: MainMenu!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Our Info.plist starts us off as background. Now that we're started, become an accessory app.
        // This approach lets us start the app deactivated.
        NSApp.setActivationPolicy(.accessory)
        schedulePtn()
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        systemMenu.open()
    }
    
    func applicationDidResignActive(_ notification: Notification) {
        systemMenu.hideItem()
    }
    
    func hideMenu() {
        DispatchQueue.main.async {
            self.systemMenu.statusMenu.cancelTracking()
        }
    }
    
    var sptn : ScheduledPtnWindowController?
    
    func schedulePtn() {
        let when = DispatchTime.now().advanced(by: DispatchTimeInterval.seconds(2))
//        DispatchQueue.main.asyncAfter(deadline: when, execute: {

        var loaded: NSArray?
        Bundle.main.loadNibNamed("ScheduledPtnWindowController", owner: self, topLevelObjects: &loaded)
        print("loaded: \(loaded?[1])")
        
            print("schedulePtn: showing window")
            self.sptn = ScheduledPtnWindowController()
            self.sptn?.show()
            print("schedulePtn: done")
//        })
    }

}

