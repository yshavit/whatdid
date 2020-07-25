import Cocoa
import HotKey

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    public static let instance = NSApplication.shared.delegate as! AppDelegate
    
    public let model = Model()
    @IBOutlet weak var scheduledPtnWindowController: SystemMenuItemManager!
    let focusHotKey = HotKey(key: .x, modifiers: [.command, .shift])
    private var deactivationHooks : Atomic<[() -> Void]> = Atomic(wrappedValue: [])
    
    func onDeactivation(_ block: @escaping () -> Void) {
        deactivationHooks.modifyInPlace {arr in
            arr.append(block)
        }
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Our Info.plist starts us off as background. Now that we're started, become an accessory app.
        // This approach lets us start the app deactivated.
        NSApp.setActivationPolicy(.accessory)
        focusHotKey.keyDownHandler = { self.scheduledPtnWindowController.focus() }
        scheduledPtnWindowController.schedulePopup()
    }
    
    func applicationDidResignActive(_ notification: Notification) {
        let oldHooks = deactivationHooks.getAndSet([])
        oldHooks.forEach {hook in
            hook()
        }
    }
}
