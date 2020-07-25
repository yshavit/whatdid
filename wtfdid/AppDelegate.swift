import Cocoa
import HotKey

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    public static let instance = NSApplication.shared.delegate as! AppDelegate
    
    public let model = Model()
    @IBOutlet weak var scheduledPtnWindowController: ScheduledPtnWindowController!
    let focusHotKey = HotKey(key: .x, modifiers: [.command, .shift])
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Our Info.plist starts us off as background. Now that we're started, become an accessory app.
        // This approach lets us start the app deactivated.
        NSApp.setActivationPolicy(.accessory)
        focusHotKey.keyDownHandler = {
            if !NSApp.isActive {
                NSApp.activate(ignoringOtherApps: true)
            }
            self.scheduledPtnWindowController.focus()
        }
        schedulePtn()
    }

    func schedulePtn() {
        let when = DispatchTime.now().advanced(by: DispatchTimeInterval.milliseconds(500))
        DispatchQueue.main.asyncAfter(deadline: when, execute: {
            self.scheduledPtnWindowController.show()
        })
    }

}

