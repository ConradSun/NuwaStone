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
    
    @IBOutlet weak var logLevelButton: NSPopUpButton!
    @IBOutlet weak var auditSwitchButton: NSPopUpButton!
    
    @IBOutlet weak var upRadioButton: NSButton!
    @IBOutlet weak var downRadioButton: NSButton!
    @IBOutlet weak var pathView: NSTextView!
    @IBOutlet weak var fileCheckButton: NSButton!
    @IBOutlet weak var networkCheckButton: NSButton!
    @IBOutlet weak var processCheckButton: NSButton!
    
    @IBOutlet weak var deviceName: NSTextField!
    @IBOutlet weak var systemVersion: NSTextField!
    @IBOutlet weak var sipStatus: NSTextField!
    @IBOutlet weak var availableStorage: NSTextField!
    @IBOutlet weak var totalStorage: NSTextField!
    @IBOutlet weak var processorArch: NSTextField!
    @IBOutlet weak var physicalMemory: NSTextField!
    @IBOutlet weak var batteryState: NSTextField!
    @IBOutlet weak var clearInterval: NSTextField!
    @IBOutlet weak var intervalSlider: NSSliderCell!
    
    @IBOutlet weak var updateButton: NSButtonCell!
    
    private var userPref = Preferences()
    private var isUpButtonChoosed = true
    private var muteChoice = MuteChoice.FilterFile
    private var muteType = NuwaMuteType.TypeNil
    private var eventProvider: NuwaEventProviderProtocol?
    
    override func viewDidLoad() {
        Preferences.registerDefaults()
        super.viewDidLoad()
        fileCheckButton.isHidden = true
        networkCheckButton.isHidden = true
        processCheckButton.isHidden = true
        upRadioButton.state = .off
        downRadioButton.state = .off
        
        if #available(macOS 11.0, *) {
            eventProvider = SextManager.shared
        } else {
            eventProvider = KextManager.shared
        }
        
        updateButton.isEnabled = eventProvider!.isExtConnected
        
        logLevelButton.selectItem(withTag: Int(NuwaLog.logLevel.rawValue))
        auditSwitchButton.selectItem(withTag: (userPref.auditSwitch ? 1 : 0))
        
        deviceName.stringValue = getDeviceName()
        systemVersion.stringValue = getSystemVersion()
        sipStatus.stringValue = getSIPStatus()
        availableStorage.stringValue = getAvailableRAM()
        totalStorage.stringValue = getTotalRAM()
        processorArch.stringValue = getProcessorArch()
        physicalMemory.stringValue = getPhysicalMemory()
        batteryState.stringValue = getBatteryState()
        
        intervalSlider.integerValue = Int(userPref.clearDuration) / 60
        sliderValueChanged(intervalSlider)
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
        case .TypeNil:
            break
        case .FilterFileByFilePath:
            pathView.string = userPref.filePathsForFileMute.joined(separator: "\n")
        case .FilterFileByProcPath:
            pathView.string = userPref.procPathsForFileMute.joined(separator: "\n")
        case .FilterNetByProcPath:
            pathView.string = userPref.procPathsForNetMute.joined(separator: "\n")
        case .FilterNetByIPAddr:
            pathView.string = userPref.ipAddrsForNetMute.joined(separator: "\n")
        case .AllowProcExec:
            pathView.string = userPref.allowExecList.joined(separator: "\n")
        case .DenyProcExec:
            pathView.string = userPref.denyExecList.joined(separator: "\n")
        }
    }
    
    @IBAction func sliderValueChanged(_ sender: NSSliderCell) {
        let timeDuration = intervalSlider.integerValue
        if timeDuration == 0 {
            clearInterval.stringValue = "Never"
            return
        }
        let minDesc = timeDuration == 1 ? "minute" : "minutes"
        clearInterval.stringValue = "\(timeDuration) \(minDesc)"
    }
    
    @IBAction func fileButtonClicked(_ sender: NSButton) {
        upRadioButton.title = "FileList"
        downRadioButton.title = "ProcList"
        muteChoice = .FilterFile
        updateCheckButton(choice: muteChoice)
        upButtonClicked(upRadioButton)
    }
    
    @IBAction func networkButtonClicked(_ sender: NSButton) {
        upRadioButton.title = "ProcList"
        downRadioButton.title = "IPList"
        muteChoice = .FilterNetwork
        networkCheckButton.isHidden = false
        updateCheckButton(choice: muteChoice)
        upButtonClicked(upRadioButton)
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
        let inputs = pathView.string.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard let eventProvider = eventProvider else {
            ViewController.displayWithWindow(text: "Event provider is not available.", style: .critical)
            return
        }
        guard let level = logLevelButton.selectedItem?.tag,
            let status = auditSwitchButton.selectedItem?.tag else {
            ViewController.displayWithWindow(text: "Please select log level and audit switch.", style: .critical)
            return
        }
        
        switch muteType {
        case .TypeNil:
            break
        case .FilterFileByFilePath:
            userPref.filePathsForFileMute = inputs
        case .FilterFileByProcPath:
            userPref.procPathsForFileMute = inputs
        case .FilterNetByProcPath:
            userPref.procPathsForNetMute = Set(inputs)
        case .FilterNetByIPAddr:
            userPref.ipAddrsForNetMute = Set(inputs)
        case .AllowProcExec:
            userPref.allowExecList = inputs
        case .DenyProcExec:
            userPref.denyExecList = inputs
        }
        if (muteType != .TypeNil) {
            _ = eventProvider.udpateMuteList(list: inputs, type: muteType)
        }
        if level != NuwaLog.logLevel.rawValue {
            let newLevel = NuwaLogLevel.from(UInt8(level))
            NuwaLog.logLevel = newLevel
            _ = eventProvider.setLogLevel(level: newLevel)
        }
        if (status > 0) != userPref.auditSwitch {
            userPref.auditSwitch = (status > 0)
        }
        if intervalSlider.doubleValue * 60 != userPref.clearDuration {
            userPref.clearDuration = intervalSlider.doubleValue * 60
            NotificationCenter.default.post(name: NSNotification.Name(DurationChanged), object: nil)
        }
        ViewController.displayWithWindow(text: "The changes are saved.", style: .informational)
    }
}
