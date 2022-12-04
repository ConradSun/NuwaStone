//
//  PrefsViewController.swift
//  NuwaClient
//
//  Created by ConradSun on 2022/9/18.
//

import Cocoa

class PrefsViewController: NSViewController {
    private enum MuteChoice {
        case FilterFile
        case FilterNetwork
        case MuteProcess
    }
    
    @IBOutlet weak var upRadioButton: NSButton!
    @IBOutlet weak var downRadioButton: NSButton!
    @IBOutlet weak var pathView: NSTextView!
    @IBOutlet weak var fileCheckButton: NSButton!
    @IBOutlet weak var networkCheckButton: NSButton!
    @IBOutlet weak var processCheckButton: NSButton!
    
    private var isUpButtonChoosed = true
    private var muteChoice = MuteChoice.FilterFile
    private var muteType = NuwaMuteType.FilterFileByFilePath
    private var eventProvider: NuwaEventProviderProtocol?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        fileCheckButton.isHidden = true
        networkCheckButton.isHidden = true
        processCheckButton.isHidden = true
        upRadioButton.state = .off
        downRadioButton.state = .off
        
        if #available(macOS 10.16, *) {
            eventProvider = SextManager.shared
        }
        else {
            eventProvider = KextManager.shared
        }
    }
    
    private func updateCheckButton(choice: MuteChoice) {
        fileCheckButton.isHidden = true
        networkCheckButton.isHidden = true
        processCheckButton.isHidden = true
        
        switch choice {
        case .FilterFile:
            fileCheckButton.isHidden = false
        case .FilterNetwork:
            networkCheckButton.isHidden = false
        case .MuteProcess:
            processCheckButton.isHidden = false
        }
    }
    
    private func displayPrefList() {
        switch muteChoice {
        case .FilterFile:
            muteType = isUpButtonChoosed ? .FilterFileByFilePath : .FilterFileByProcPath
        case .FilterNetwork:
            muteType = isUpButtonChoosed ? .FilterNetByProcPath : .FilterNetByIPAddr
        case .MuteProcess:
            muteType = isUpButtonChoosed ? .AllowProcExec : .DenyProcExec
        }
        
        switch muteType {
        case .FilterFileByFilePath:
            pathView.string = PrefPathList.shared.filePathsForFileMute.joined(separator: "\n")
        case .FilterFileByProcPath:
            pathView.string = PrefPathList.shared.procPathsForFileMute.joined(separator: "\n")
        case .FilterNetByProcPath:
            pathView.string = PrefPathList.shared.procPathsForNetMute.joined(separator: "\n")
        case .FilterNetByIPAddr:
            pathView.string = PrefPathList.shared.ipAddrsForNetMute.joined(separator: "\n")
        case .AllowProcExec:
            pathView.string = PrefPathList.shared.allowExecList.joined(separator: "\n")
        case .DenyProcExec:
            pathView.string = PrefPathList.shared.denyExecList.joined(separator: "\n")
        }
    }
    
    @IBAction func fileButtonClicked(_ sender: NSButton) {
        upRadioButton.title = "FileList"
        downRadioButton.title = "ProcList"
        muteChoice = .FilterFile
        updateCheckButton(choice: muteChoice)
        upButtonClicked(upRadioButton)
        Logger(.Info, "fileButtonClicked")
    }
    
    @IBAction func networkButtonClicked(_ sender: NSButton) {
        upRadioButton.title = "ProcList"
        downRadioButton.title = "IPList"
        muteChoice = .FilterNetwork
        networkCheckButton.isHidden = false
        updateCheckButton(choice: muteChoice)
        upButtonClicked(upRadioButton)
        Logger(.Info, "networkButtonClicked")
    }
    
    @IBAction func processButtonClicked(_ sender: NSButton) {
        upRadioButton.title = "AllowList"
        downRadioButton.title = "DenyList"
        muteChoice = .MuteProcess
        processCheckButton.isHidden = false
        updateCheckButton(choice: muteChoice)
        upButtonClicked(upRadioButton)
    }
    
    @IBAction func upButtonClicked(_ sender: NSButton) {
        upRadioButton.state = .on
        downRadioButton.state = .off
        isUpButtonChoosed = true
        displayPrefList()
    }
    
    @IBAction func downButtonClicked(_ sender: NSButton) {
        upRadioButton.state = .off
        downRadioButton.state = .on
        isUpButtonChoosed = false
        displayPrefList()
    }
    
    @IBAction func closeButtonClicked(_ sender: NSButton) {
        view.window?.close()
    }
    
    @IBAction func updateButtonClicked(_ sender: NSButton) {
        let inputs = pathView.string.components(separatedBy: "\n")
        
        switch muteType {
        case .FilterFileByFilePath, .FilterFileByProcPath:
            PrefPathList.shared.updateMuteFileList(paths: inputs, type: muteType)
            _ = eventProvider!.udpateMuteList(list: inputs, type: muteType)
            
        case .FilterNetByProcPath, .FilterNetByIPAddr:
            PrefPathList.shared.updateMuteNetworkList(values: inputs, type: muteType)
            // _ = eventProvider!.udpateMuteList(list: inputs, type: muteType)
            
        case .AllowProcExec, .DenyProcExec:
            PrefPathList.shared.updateMuteExecList(paths: inputs, type: muteType)
            _ = eventProvider!.udpateMuteList(list: inputs, type: muteType)
        }
        
        view.window?.close()
    }
}
