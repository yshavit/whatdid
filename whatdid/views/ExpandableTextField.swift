// whatdid?

import Cocoa

class ExpandableTextField: NSView, NSTextFieldDelegate {
    
    private static let minEditingSize: CGFloat = 100
    private let button = createAddButton()
    fileprivate let field = NSTextField(string: "")
    private var fieldWidthExpanded: NSLayoutConstraint!
    var expandCollapseHook: (() -> Void)?
    var goalHook: ((String) -> Void)?
    
    private static func createAddButton() -> NSButton {
        let button: NSButton
        if let image = NSImage(named: NSImage.touchBarAddDetailTemplateName) {
            button = NSButton(image: image, target: nil, action: nil)
            button.isBordered = false
        } else {
            button = NSButton(title: "+⃣", target: self, action: nil)
            button.bezelStyle = .texturedRounded
        }
        button.controlSize = .small
        button.toolTip = "Add new goal"
        button.setAccessibilityEnabled(true)
        button.setAccessibilityElement(true)
        button.setAccessibilityLabel(button.toolTip)
        button.setAccessibilityIdentifier(button.toolTip)
        button.setAccessibilityRole(.button)
        return button
    }
    
    var isExpanded: Bool {
        get {
            return !field.isHidden
        }
        set (expanded) {
            field.isHidden = !expanded
            setWidth(to: expanded ? ExpandableTextField.minEditingSize : 0)
        }
    }
    
    private func setWidth(to width: CGFloat) {
        fieldWidthExpanded.constant = width
        invalidateIntrinsicContentSize()
        if let hook = expandCollapseHook {
            hook()
        }
    }
    
    func controlTextDidChange(_ obj: Notification) {
        if let cell = field.cell as? NSTextFieldCell {
            // For some reason, we need to read the cell's stringValue to get it to refresh its contents
            // and thus report the right size. This must be un-sticking some cache.
            let _ = cell.stringValue
            let currentHeight = cell.cellSize.height
            var maxWidth = ExpandableTextField.minEditingSize
            if let superviewWidth = superview?.bounds.width {
                maxWidth = superviewWidth - button.intrinsicContentSize.width - 20 // -20 to give some buffer for bezels etc
            }
            let maxBounds = NSRect(x: field.bounds.minX, y: field.bounds.minY, width: maxWidth, height: currentHeight * 10)
            let textWidth = cell.cellSize(forBounds: maxBounds).width
            setWidth(to: max(ExpandableTextField.minEditingSize, textWidth))
        }
    }
    
    override var intrinsicContentSize: NSSize {
        get {
            var size = button.intrinsicContentSize
            if isExpanded {
                size.width += fieldWidthExpanded.constant
            }
            return size
        }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        doInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        doInit()
    }
    
    func makeFirstResponder(for window: NSWindow) {
        window.makeFirstResponder(field)
    }
    
    var currentEditor: NSText? {
        get {
            field.currentEditor()
        }
    }
    
    var font: NSFont? {
        get {
            field.font
        }
        set (value) {
            field.font = value
        }
    }
    
    var controlSize: NSControl.ControlSize {
        get {
            field.controlSize
        }
        set (value) {
            field.controlSize = value
        }
    }
    
    func set(font: NSFont) {
        field.font = font
    }
    
    private func doInit() {
        useAutoLayout()
        setContentHuggingPriority(.required, for: .horizontal)
        
        addSubview(field)
        field.bezelStyle = .roundedBezel
        fieldWidthExpanded = field.widthAnchor.constraint(greaterThanOrEqualToConstant: ExpandableTextField.minEditingSize)
        fieldWidthExpanded.isActive = true
        field.useAutoLayout()
        field.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
        field.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        field.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        field.target = self
        field.action = #selector(self.goalEntered)
        field.cell?.sendsActionOnEndEditing = false
        field.delegate = self
        
        addSubview(button)
        button.useAutoLayout()
        button.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
        button.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        button.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        
        isExpanded = false
        button.trailingAnchor.constraint(equalTo: field.trailingAnchor, constant: -2).isActive = true
        
        button.action = #selector(self.expandAddButton(_:))
        button.target = self
    }
    
    @objc private func expandAddButton(_ button: NSButton) {
        if isExpanded {
            goalEntered() // will also toggle expansion
        } else {
            toggleExpansion()
            window?.makeFirstResponder(field)
        }
    }
    
    private func toggleExpansion() {
        NSAnimationContext.runAnimationGroup {context in
            context.duration = 0.5
            context.allowsImplicitAnimation = true
            isExpanded = !isExpanded
        }
    }
    
    @objc private func goalEntered() {
        if let hook = goalHook {
            hook(field.stringValue)
        }
        field.stringValue = ""
        toggleExpansion()
    }
}
