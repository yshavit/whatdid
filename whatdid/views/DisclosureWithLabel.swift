// whatdid?

import Cocoa
import SwiftUI

@IBDesignable
class DisclosureWithLabel: NSView {
    
    private let disclosureButton = NSButton(title: "", target: nil, action: nil)
    private let labelButton = NSButton(title: "Show", target: nil, action: nil)
    private var _detailsView: NSView?
    private var _labelText = ""
    
    var onToggle: (Bool) -> Void = {_ in }

    var detailsView: NSView? {
        get {
            _detailsView
        }
        set (value) {
            _detailsView = value
            updateViews()
        }
    }
    
    var title: String {
        get {
            _labelText
        }
        set (value) {
            _labelText = value
            updateViews()
        }
    }
    
    var controlSize: NSControl.ControlSize {
        get {
            labelButton.controlSize
        }
        set (value) {
            labelButton.controlSize = value
        }
    }
    
    var isShowingDetails: Bool {
        get {
            disclosureButton.state == .on
        }
        set (value) {
            disclosureButton.state = value ? .on : .off
            updateViews()
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
    
    private func doInit() {
        disclosureButton.bezelStyle = .disclosure
        disclosureButton.setButtonType(.pushOnPushOff)
        
        labelButton.isBordered = false
        labelButton.bezelStyle = .regularSquare
        labelButton.refusesFirstResponder = true
        [labelButton, disclosureButton].forEach {b in
            b.target = self
            b.action = #selector(handleClick(_:))
        }
        
        let hstack = NSStackView(orientation: .horizontal)
        hstack.spacing = 2
        hstack.alignment = .centerY
        hstack.addArrangedSubview(disclosureButton)
        hstack.addArrangedSubview(labelButton)
        
        addSubview(hstack)
        hstack.anchorAllSides(to: self)
    }

    override func setAccessibilityIdentifier(_ accessibilityIdentifier: String?) {
        disclosureButton.setAccessibilityIdentifier(accessibilityIdentifier)
    }
    
    override func prepareForInterfaceBuilder() {
        doInit()
        invalidateIntrinsicContentSize()
    }
    
    @objc private func handleClick(_ sender: NSButton) {
        if (sender == labelButton) {
            disclosureButton.performClick(nil)
        }
        updateViews()
    }
    
    private func updateViews() {
        let detailIsShowing = isShowingDetails
        let wasHidingDetails = detailsView?.isHidden ?? false
        detailsView?.isHidden = !detailIsShowing
        let verb = detailIsShowing ? "Hide" : "Show"
        labelButton.title = _labelText.isEmpty ? verb : "\(verb) \(_labelText)"
        
        onToggle(detailIsShowing)
        let isHidingDetails = detailsView?.isHidden ?? false
        // The onToggle must have re-flipped us. Make the toggle state reflects that.
        disclosureButton.state = isHidingDetails ? .off : .on
        
        if isHidingDetails != wasHidingDetails, let window = self.window, let contentView = window.contentView {
            // This is the expected case
            window.setContentSize(contentView.fittingSize)
        }
    }
}
