// whatdid?

import Cocoa

class NonFocusingNSViewController: NSViewController {

    override func viewDidAppear() {
        self.view.window?.makeFirstResponder(self.view)
    }
    
}
