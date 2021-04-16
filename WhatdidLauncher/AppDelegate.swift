// Taken from https://theswiftdev.com/how-to-launch-a-macos-app-at-login/

import Cocoa
import os

extension Notification.Name {
    static let killLauncher = Notification.Name("killLauncher")
}

@NSApplicationMain
class AppDelegate: NSObject {

    @objc func terminate() {
        NSApp.terminate(nil)
    }
}

extension AppDelegate: NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let mainAppIdentifier = "com.yuvalshavit.whatdid"
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = !runningApps.filter { $0.bundleIdentifier == mainAppIdentifier }.isEmpty

        if isRunning {
            os_log(.info, "whatdid launcher: whatdid is already running")
            self.terminate()
        } else {
            os_log(.info, "whatdid launcher: will try to launch whatdid")
            DistributedNotificationCenter.default().addObserver(self, selector: #selector(self.terminate), name: .killLauncher, object: mainAppIdentifier)

            let path = Bundle.main.bundlePath as NSString
            var components = path.pathComponents
            components.removeLast()
            components.removeLast()
            components.removeLast()
            components.append("MacOS")
            components.append("whatdid") //main app name

            let newPath = NSString.path(withComponents: components)
            os_log(.info, "whatdid launcher about to launch: %@", newPath)

            NSWorkspace.shared.launchApplication(newPath)
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        os_log(.info, "whatdid launcher is exiting")
    }
}
