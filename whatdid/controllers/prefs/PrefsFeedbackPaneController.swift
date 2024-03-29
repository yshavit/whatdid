//
//  PrefsFeedbackPaneController.swift
//  whatdid
//
//  Created by Yuval Shavit on 10/9/23.
//  Copyright © 2023 Yuval Shavit. All rights reserved.
//

import Cocoa

class PrefsFeedbackPaneController: NSViewController, NSTextFieldDelegate {
    
    @IBOutlet var feedbackButton: NSButton!
    @IBOutlet weak var privacyUrl: HrefButton!
    
    override func viewDidLoad() {
        if let versionQuery = Version.pretty.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            feedbackButton.toolTip = feedbackButton.toolTip?.replacingBracketedPlaceholders(with: [
                "version": versionQuery
            ])
        } else {
            feedbackButton.removeFromSuperview()
        }
        privacyUrl.toolTip = UsageTracking.PRIVACY_URL
    }

    @IBInspectable
    dynamic var allowAnalytics: Bool {
        get { Prefs.analyticsEnabled }
        set(value) { Prefs.analyticsEnabled = value}
    }
    
    @IBAction func showTutorial(_ sender: Any) {
        if let myWindow = view.window, let mySheetParent = myWindow.sheetParent {
            mySheetParent.endSheet(myWindow, returnCode: PrefsViewController.SHOW_TUTORIAL)
        }
    }
    
    @IBAction func href(_ sender: NSButton) {
        if let location = sender.toolTip, let url = URL(string: location) {
            NSWorkspace.shared.open(url)
        } else {
            wdlog(.warn, "invalid href: %@", sender.toolTip ?? "<nil>")
        }
    }
}
