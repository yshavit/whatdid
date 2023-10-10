//
//  HrefButton.swift
//  whatdid
//
//  Created by Yuval Shavit on 10/9/23.
//  Copyright © 2023 Yuval Shavit. All rights reserved.
//

import Cocoa

class HrefButton: NSButton {
    
    override func sendAction(_ action: Selector?, to target: Any?) -> Bool {
        if let location = toolTip, let url = URL(string: location) {
            NSWorkspace.shared.open(url)
        } else {
            wdlog(.warn, "invalid href: %@", toolTip ?? "<nil>")
        }
        super.sendAction(action, to: target)
        return true
    }
}
