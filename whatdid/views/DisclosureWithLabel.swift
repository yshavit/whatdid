// whatdid?

import Cocoa
import SwiftUI

@IBDesignable
class DisclosureWithLabel: NSView {
    
    private let disclosureButton = NSButton(title: "", target: nil, action: nil)
    private let labelButton = NSButton(title: "Show", target: nil, action: nil)
    private var _detailsView: NSView?
    private var _labelText = ""

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
        disclosureButton.state == .on
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
        [labelButton, disclosureButton].forEach {b in
            b.target = self
            b.action = #selector(handleClick(_:))
        }
        
        let hstack = NSStackView(orientation: .horizontal)
        hstack.alignment = .centerY
        hstack.addArrangedSubview(disclosureButton)
        hstack.addArrangedSubview(labelButton)
        addSubview(hstack)
        hstack.anchorAllSides(to: self)
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
        detailsView?.isHidden = !detailIsShowing
        let verb = detailIsShowing ? "Hide" : "Show"
        labelButton.title = _labelText.isEmpty ? verb : "\(verb) \(_labelText)"
    }
}
