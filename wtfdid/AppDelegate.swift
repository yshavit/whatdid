import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    public static let instance = NSApplication.shared.delegate as! AppDelegate
    
    public lazy var model = Model()
    @IBOutlet private weak var systemMenu: MainMenu!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Our Info.plist starts us off as background. Now that we're started, become an accessory app.
        // This approach lets us start the app deactivated.
        NSApp.setActivationPolicy(.accessory)
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

}

