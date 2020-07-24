import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    public static let instance = NSApplication.shared.delegate as! AppDelegate
    
    public let model = Model()
    @IBOutlet private weak var systemMenu: MainMenu!
    @IBOutlet weak var sptn: ScheduledPtnWindowController!
    
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

    func schedulePtn() {
        let when = DispatchTime.now().advanced(by: DispatchTimeInterval.seconds(2))
        DispatchQueue.main.asyncAfter(deadline: when, execute: {
            self.sptn.show()
        })
    }

}

