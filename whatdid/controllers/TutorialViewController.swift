// whatdid?

import Cocoa

class TutorialViewController: NSViewController {
    
    private var steps = [Step]()
    private var currentStep = 0
    private let popover = NSPopover()
    private let highlighWindow = NSWindow()
    
    @IBOutlet var pageNum: NSTextField!
    @IBOutlet var pageCount: NSTextField!
    @IBOutlet var pageTitle: NSTextField!
    @IBOutlet var pageText: NSTextField!
    @IBOutlet var extraViewContainer: NSView!
    @IBOutlet var pageHeight: NSLayoutConstraint!
    
    @IBOutlet var backButton: NSButton!
    @IBOutlet var forwardButton: NSButton!
    
    override func awakeFromNib() {
        updatePageCount()
        
        
        highlighWindow.isOpaque = false
        highlighWindow.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0)
        highlighWindow.level = .popUpMenu
        highlighWindow.styleMask = [.borderless, .fullSizeContentView, .nonactivatingPanel]
        
        let box = NSBox()
        box.boxType = .custom
        box.titlePosition = .noTitle
        box.borderColor = NSColor.findHighlightColor.withAlphaComponent(0.75)
        box.borderWidth = 3
        box.cornerRadius = 7
        highlighWindow.contentView = box
    }
    
    func show() {
        popover.contentViewController = self
        currentStep = -1
        step(forward: true)
    }
    
    override func viewDidDisappear() {
        highlighWindow.setIsVisible(false)
    }
    
    func add(_ steps: Step...) {
        self.steps.append(contentsOf: steps)
        updatePageCount()
    }
    
    private func updatePageCount() {
        if pageCount != nil {
            pageCount.stringValue = "\(steps.count)"
        }
    }
    
    private func step(forward: Bool) {
        if currentStep >= 0 && currentStep < steps.count {
            steps[currentStep].lifecycleHandlers.forEach {h in h.onDisappear()}
        }
        currentStep += (forward ? 1 : -1)
        guard (0..<steps.count).contains(currentStep) else {
            return
        }
        let step = steps[currentStep]
        popover.show(relativeTo: NSRect(), of: step.pointingTo, preferredEdge: step.atEdge)
        
        pageNum.stringValue = "\(currentStep + 1)"
        pageTitle.stringValue = step.title
        pageText.stringValue = step.text.joined(separator: "\n\n")
        extraViewContainer.subviews.forEach { $0.removeFromSuperview() }
        if let extraView = step.extraView {
            extraViewContainer.addSubview(extraView)
            extraView.anchorAllSides(to: extraViewContainer)
        }
        backButton.isEnabled = (currentStep > 0)
        forwardButton.isEnabled = (currentStep < (steps.count - 1))
        pageHeight.constant = view.subviews.map({$0.fittingSize.height}).reduce(0, +)
        
        if step.highlight != .none, let window = step.pointingTo.window {
            var frameBorder = step.pointingTo.bounds
            frameBorder = step.pointingTo.convert(frameBorder, to: nil)
            frameBorder = window.convertToScreen(frameBorder)
            if step.highlight == .normal {
                frameBorder = frameBorder.insetBy(dx: -5, dy: -5)
            }
            highlighWindow.setContentSize(frameBorder.size)
            highlighWindow.setFrame(frameBorder, display: true)
            if !highlighWindow.isVisible {
                highlighWindow.setIsVisible(true)
            }
        } else {
            highlighWindow.setIsVisible(false)
        }
        step.lifecycleHandlers.forEach {h in h.onAppear() }
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
        let text: [String]
        let pointingTo: NSView
        let atEdge: NSRectEdge
        let extraView: NSView?
        let highlight: HighlightMode
        let lifecycleHandlers: [LifecycleHandler]
        
        init(title: String, text: [String], pointingTo: NSView, atEdge: NSRectEdge, extraView: NSView? = nil, highlight: HighlightMode = .normal, lifecycleHandlers: [LifecycleHandler] = []) {
            self.title = title
            self.text = text
            self.pointingTo = pointingTo
            self.atEdge = atEdge
            self.extraView = extraView
            self.highlight = highlight
            self.lifecycleHandlers = lifecycleHandlers
        }
    }
    
    enum HighlightMode {
        case normal
        case none
        case exactSize
    }
}

protocol LifecycleHandler {
    func onAppear()
    func onDisappear()
}
