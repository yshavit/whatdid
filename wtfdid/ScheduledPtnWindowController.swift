//
//  ScheduledPtnWindowController.swift
//  wtfdid
//
//  Created by Yuval Shavit on 7/24/20.
//  Copyright © 2020 Yuval Shavit. All rights reserved.
//

import Cocoa

class ScheduledPtnWindowController: NSWindowController, NSWindowDelegate, NSMenuDelegate {
    private static let POPUP_WINDOW_BUFFER = 3
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    private var taskAdditionsPane : TaskAdditionViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        window?.level = .floating
        taskAdditionsPane = TaskAdditionViewController()
        taskAdditionsPane.closeAction = {
            DispatchQueue.main.async {
                self.window?.close()
            }
        }
        window?.contentViewController = taskAdditionsPane
        self.window?.delegate = self
        self.window?.standardWindowButton(.closeButton)?.isHidden = true
        
        statusItem.button?.title = "✐"
        statusItem.button?.target = self
        statusItem.button?.action = #selector(showAndFocus)
    }
    
    @objc func showAndFocus() {
        if window?.isVisible ?? false {
            window?.close()
        } else {
            show()
            focus()
        }
    }
    
    func show() {
        if let mainFrame = NSScreen.main?.visibleFrame, let button = statusItem.button {
            let buttonBoundsAbsolute = button.window?.convertToScreen(button.bounds)
            let pos = NSPoint(
                x: buttonBoundsAbsolute?.minX ?? .zero,
                y: mainFrame.origin.y + mainFrame.height)
            window?.setFrameTopLeftPoint(pos)
        }
        showWindow(self)
        DispatchQueue.main.async {
            self.statusItem.button?.isHighlighted = true
        }
    }
    
    func focus() {
        if !NSApp.isActive {
            NSApp.activate(ignoringOtherApps: true)
        }
        if window?.isVisible ?? false {
            window?.makeKeyAndOrderFront(self)
        }
    }
    
    func windowWillClose(_ notification: Notification) {
        NSApp.hide(self)
        statusItem.button?.isHighlighted = false
        schedulePopup()
    }

    func schedulePopup() {
        let when = DispatchTime.now().advanced(by: DispatchTimeInterval.milliseconds(1500))
        DispatchQueue.main.asyncAfter(deadline: when, execute: {
            self.show()
        })
    }
}
