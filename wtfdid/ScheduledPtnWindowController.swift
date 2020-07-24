//
//  ScheduledPtnWindowController.swift
//  wtfdid
//
//  Created by Yuval Shavit on 7/24/20.
//  Copyright © 2020 Yuval Shavit. All rights reserved.
//

import Cocoa

class ScheduledPtnWindowController: NSWindowController, NSWindowDelegate {
    private static let POPUP_WINDOW_BUFFER = 3
    private var taskAdditionsPane : TaskAdditionViewController!
    
    @IBOutlet private weak var panel: NSPanel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        window?.level = .floating
        taskAdditionsPane = TaskAdditionViewController()
        taskAdditionsPane.closeAction = {
            DispatchQueue.main.async {
                self.window?.orderOut(self)
            }
        }
        window?.contentViewController = taskAdditionsPane
        panel.becomesKeyOnlyIfNeeded = true
    }
    
    func show() {
        if let mainFrame = NSScreen.main?.visibleFrame, let currWindow = window {
            let buffer = CGFloat(ScheduledPtnWindowController.POPUP_WINDOW_BUFFER)
            let pos = NSPoint(
                x: mainFrame.origin.x + mainFrame.width - currWindow.frame.width - buffer,
                y: mainFrame.origin.y + mainFrame.height - buffer)
            currWindow.setFrameTopLeftPoint(pos)
        }
        showWindow(self)
    }
    
    func focus() {
        if window?.isVisible ?? false {
            window?.makeKeyAndOrderFront(self)
        }
    }
}
