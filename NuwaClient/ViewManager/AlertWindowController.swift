//
//  AlertWindowController.swift
//  NuwaClient
//
//  Created by ConradSun on 2022/8/18.
//

import Cocoa

class AlertWindowController: NSWindowController {
    @IBOutlet weak var procIconView: NSImageView!
    @IBOutlet weak var procInfoText: NSTextFieldCell!
    @IBOutlet weak var eventDescLabel: NSTextField!
    @IBOutlet weak var decisionPopUP: NSPopUpButton!
    @IBOutlet weak var decisionCheckbox: NSButton!
    @IBOutlet weak var submitButton: NSButton!
    
    var authEvent: NuwaEventInfo?
    var isAllowed = false
    var shouldAddToList = false
    var eventProvider: NuwaEventProviderProtocol?
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        if #available(macOS 10.16, *) {
            eventProvider = SextManager()
        }
        else {
            eventProvider = KextManager()
        }
        
        let icon = NSWorkspace.shared.icon(forFile: authEvent!.procPath)
        icon.size = NSMakeSize(96, 96)
        procIconView.image = icon
        procInfoText.stringValue = authEvent!.props[PropBundleID]!
        eventDescLabel.stringValue = authEvent!.desc
        decisionCheckbox.title = "Only this time (pid: \(authEvent!.pid))"
    }
    
    @IBAction func submitButtonClicked(_ sender: Any) {
        isAllowed = decisionPopUP.selectedItem?.title == "Allow"
        shouldAddToList = decisionCheckbox.state == .on
        _ = eventProvider?.replyAuthEvent(eventID: authEvent!.eventID, isAllowed: isAllowed)
        window?.close()
    }
}