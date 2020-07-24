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
    
    override func awakeFromNib() {
        super.awakeFromNib()
        print("awakening: window=\(window), self=\(self)")
        window?.level = .floating
        taskAdditionsPane = TaskAdditionViewController()
        window?.contentViewController = taskAdditionsPane
        print("awakened: window=\(window)")
    }
    
    func show() {
        print("showing (window=\(window)), self=\(self)")
        if let mainFrame = NSScreen.main?.visibleFrame, let currWindow = window {
            print("yes")
            let buffer = CGFloat(ScheduledPtnWindowController.POPUP_WINDOW_BUFFER)
            let pos = NSPoint(
                x: mainFrame.origin.x + mainFrame.width - currWindow.frame.width - buffer,
                y: mainFrame.origin.y + mainFrame.height - buffer)
            currWindow.setFrameTopLeftPoint(pos)
        }
        showWindow(self)
    }
    
}
