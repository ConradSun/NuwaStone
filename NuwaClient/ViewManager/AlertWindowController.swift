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
    var isSubmitted = false
    var eventProvider: NuwaEventProviderProtocol?
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        if #available(macOS 11.0, *) {
            eventProvider = SextManager.shared
        }
        else {
            eventProvider = KextManager.shared
        }
        
        let icon = NSWorkspace.shared.icon(forFile: authEvent!.procPath)
        icon.size = NSMakeSize(96, 96)
        procIconView.image = icon
        procInfoText.stringValue = authEvent!.props[PropBundleID] ?? authEvent!.procPath
        eventDescLabel.stringValue = authEvent!.desc
        decisionCheckbox.title = "Only this time (pid: \(authEvent!.pid))"
        
        let waitTime = DispatchTime.now() + .milliseconds(MaxWaitTime-500)
        DispatchQueue.main.asyncAfter(deadline: waitTime) {
            self.submitButtonClicked(self.submitButton)
        }
    }
    
    @IBAction func submitButtonClicked(_ sender: NSButton) {
        if isSubmitted {
            return
        }
        
        isSubmitted = true
        isAllowed = decisionPopUP.selectedItem?.title == "Allow"
        let muteType = isAllowed ? NuwaMuteType.AllowProcExec : NuwaMuteType.DenyProcExec
        shouldAddToList = decisionCheckbox.state == .off
        _ = eventProvider!.replyAuthEvent(eventID: authEvent!.eventID, isAllowed: isAllowed)
        if shouldAddToList {
            _ = eventProvider!.udpateMuteList(list: [authEvent!.procPath], type: muteType)
            PrefPathList.shared.appendMuteExecList(path: authEvent!.procPath, type: muteType)
        }
        window?.close()
        authEvent = nil
    }
}
