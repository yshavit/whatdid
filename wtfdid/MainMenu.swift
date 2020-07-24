//
//  MainMenuController.swift
//  wtfdid
//
//  Created by Yuval Shavit on 12/23/19.
//  Copyright © 2019 Yuval Shavit. All rights reserved.
//

import Cocoa

class MainMenu: NSObject, NSMenuDelegate {
    
    @IBOutlet weak var statusMenu: NSMenu!
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    // I'm not sure why, but taskAdditionView needs to be a var (not let), and needs to be initialized in open (not awakeFromNib).
    // Otherwise, its fields NPE.
    var taskAdditionView: TaskAdditionViewController?
    
    override func awakeFromNib() {
        statusItem.button?.title = "✐"
        statusItem.menu = statusMenu
        statusMenu.delegate = self
        
    }
    
    /**
    See `menuWillOpen(_)`
    */
    func open() {
        if taskAdditionView == nil {
            taskAdditionView = TaskAdditionViewController()
            taskAdditionView?.closeAction = {
                AppDelegate.instance.hideMenu()
            }
        }
        let newItem = NSMenuItem(title: "Error", action: nil, keyEquivalent: "")
        newItem.view = taskAdditionView?.view
        statusMenu.addItem(newItem)
        statusItem.button?.performClick(nil)
    }
    
    /**
     See `menuWillOpen(_)`
     */
    func hideItem() {
        statusMenu.removeAllItems()
    }

    /**
     The lifecycle here is a bit odd. We basically have two modes: if the app is already active, and if it's not.
     In order to type into the fiels, the app needs to be active; but activating it once the view is up actually hides the view!
     
     To handle that, we handle the two modes very differently:
     
     1. If the app is inactive, the menu will have no items (see `hideItem()` in this class). In this case, all we do in this method is to activate.
     2. If the app is active, the menu will have items (see `open()`). In this case, we tell the view to grab focus.
     */
    func menuWillOpen(_ menu: NSMenu) {
        if !NSRunningApplication.current.isActive {
            NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])
        } else {
            taskAdditionView?.grabFocus()
        }
    }
    
    func menuDidClose(_ menu: NSMenu) {
        taskAdditionView?.reset()
    }
}
