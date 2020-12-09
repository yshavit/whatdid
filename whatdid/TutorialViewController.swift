// whatdid?

import Cocoa

class TutorialViewController: NSViewController {
    
    private var steps = [Step]()
    private var currentStep = 0
    private let popover = NSPopover()
    
    @IBOutlet var pageNum: NSTextField!
    @IBOutlet var pageCount: NSTextField!
    @IBOutlet var pageTitle: NSTextField!
    @IBOutlet var pageText: NSTextField!
    @IBOutlet var pageHeight: NSLayoutConstraint!
    
    @IBOutlet var backButton: NSButton!
    @IBOutlet var forwardButton: NSButton!
    
    override func awakeFromNib() {
        updatePageCount()
    }
    
    func show() {
        popover.contentViewController = self
        currentStep = -1
        step(forward: true)
    }
    
    func add(_ step: Step) {
        steps.append(step)
        updatePageCount()
    }
    
    private func updatePageCount() {
        if pageCount != nil {
            pageCount.stringValue = "\(steps.count)"
        }
    }
    
    private func step(forward: Bool) {
        currentStep += (forward ? 1 : -1)
        guard (0..<steps.count).contains(currentStep) else {
            return
        }
        let step = steps[currentStep]
        popover.show(relativeTo: NSRect(), of: step.pointingTo, preferredEdge: step.atEdge)
        
        pageNum.stringValue = "\(currentStep + 1)"
        pageTitle.stringValue = step.title
        pageText.stringValue = step.text
        backButton.isEnabled = (currentStep > 0)
        forwardButton.isEnabled = (currentStep < (steps.count - 1))
        pageHeight.constant = view.subviews.map({$0.fittingSize.height}).reduce(0, +)
    }
    
    @IBAction func close(_ sender: Any) {
        popover.performClose(self)
    }
    
    @IBAction func stepBack(_ sender: Any) {
        step(forward: false)
    }
    
    @IBAction func stepForward(_ sender: Any) {
        step(forward: true)
    }
    
    struct Step {
        let title: String
        let text: String
        let pointingTo: NSView
        let atEdge: NSRectEdge
    }
}
