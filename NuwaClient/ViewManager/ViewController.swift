//
//  ViewController.swift
//  NuwaClient
//
//  Created by ConradSun on 2022/7/9.
//

import Cocoa

/// Type for event displaying
enum DisplayMode: Int, CaseIterable {
    case DisplayAll
    case DisplayProcess
    case DisplayFile
    case DisplayNetwork
}

class ViewController: NSViewController {
    @IBOutlet weak var controlButton: NSButton!
    @IBOutlet weak var scrollButton: NSButton!
    @IBOutlet weak var clearButton: NSButton!
    @IBOutlet weak var InfoButton: NSButton!
    @IBOutlet weak var controlLabel: NSTextField!
    @IBOutlet weak var displaySegment: NSSegmentedControl!
    @IBOutlet weak var searchBar: NSSearchField!
    @IBOutlet weak var eventView: NSTableView!
    @IBOutlet weak var infoLabel: NSTextField!
    @IBOutlet weak var splitView: NSSplitView!
    @IBOutlet weak var graphView: GraphView!
    
    var isStarted = false
    var isScrollOn = true
    var isInfoOn = true
    var searchText = ""
    var displayMode = DisplayMode.DisplayAll
    var displayTimer = Timer()
    var clearTimer = Timer()
    
    let eventQueue = DispatchQueue(label: "com.nuwastone.eventview.queue", attributes: .concurrent)
    var eventCount = [UInt32](repeating: 0, count: DisplayMode.allCases.count)
    var eventCountCopy = [UInt32](repeating: 0, count: DisplayMode.allCases.count)
    var reportedItems = [NuwaEventInfo]()
    var displayedItems = [NuwaEventInfo]()
    
    var userPref = Preferences()
    var eventProvider: NuwaEventProviderProtocol?
    var alertWindow: AlertWindowController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(macOS 11.0, *) {
            eventProvider = SextManager.shared
        } else {
            eventProvider = KextManager.shared
        }
        eventProvider!.processDelegate = self
        
        eventView.delegate = self
        eventView.dataSource = self
        eventView.target = self
        setupPrefs()
        establishConnection()
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    @IBAction func controlButtonClicked(_ sender: NSButton) {
        if !isStarted {
            DispatchQueue.global().async { [self] in
                ProcessCache.shared.initProcCache()
                // Failed to start monitoring, reset status
                if !eventProvider!.startProvider() {
                    DispatchQueue.main.sync {
                        ViewController.displayWithWindow(text: "Failed to connect extension.", style: .critical)
                        controlButton.image = NSImage(named: "start")
                        controlLabel.stringValue = "start"
                        isStarted = false
                    }
                    return
                }
                
                // Start monitoring successfully, set status to wait for stop
                DispatchQueue.main.sync {
                    initMutePaths()
                    setupDisplayTimer()
                    setupClearTimer()
                }
            }
            
            controlButton.image = NSImage(named: "stop")
            controlLabel.stringValue = "stop"
            isStarted = true
        } else {
            if !eventProvider!.stopProvider() {
                ViewController.displayWithWindow(text: "Failed to disconnect extension.", style: .critical)
                return
            }
            
            // Stop monitoring successfully, set status to wait for start
            controlButton.image = NSImage(named: "start")
            controlLabel.stringValue = "start"
            isStarted = false
            displayTimer.invalidate()
            clearTimer.invalidate()
        }
        configMenuStatus(start: !isStarted, stop: isStarted)
    }
    
    @IBAction func scrollButtonClicked(_ sender: NSButton) {
        isScrollOn = !isScrollOn
        if isScrollOn {
            scrollButton.image = NSImage(named: "scroll-on")
        } else {
            scrollButton.image = NSImage(named: "scroll-off")
        }
    }
    
    @IBAction func clearButtonClicked(_ sender: NSButton) {
        eventQueue.async(flags: .barrier) {
            self.reportedItems.removeAll()
            self.displayedItems.removeAll()
        }
        
        reloadEventInfo()
        infoLabel.stringValue = ""
    }
    
    @IBAction func infoButtonClicked(_ sender: NSButton) {
        isInfoOn = !isInfoOn
        if isInfoOn {
            InfoButton.image = NSImage(named: "show-on")
            splitView.arrangedSubviews[1].isHidden = false
        } else {
            infoLabel.stringValue = ""
            InfoButton.image = NSImage(named: "show-off")
            splitView.arrangedSubviews[1].isHidden = true
        }
    }
    
    @IBAction func displaySegmentValueChanged(_ sender: NSSegmentedControl) {
        if displaySegment.selectedSegment != displayMode.rawValue {
            displayMode = DisplayMode(rawValue: displaySegment.selectedSegment) ?? .DisplayAll
            graphView.displayMode = displayMode
            refreshDisplayedEvents()
        }
    }
    
    @IBAction func searchBarTextModified(_ sender: NSSearchField) {
        searchText = searchBar.stringValue
        refreshDisplayedEvents()
    }
    
    @IBAction func startMenuItemSelected(_ sender: NSMenuItem) {
        controlButtonClicked(controlButton)
    }
    
    @IBAction func stopMenuItemSelected(_ sender: NSMenuItem) {
        controlButtonClicked(controlButton)
    }
    
    @IBAction func clearMenuItemSelected(_ sender: NSMenuItem) {
        clearButtonClicked(clearButton)
    }
    
    @IBAction func uninstallMenuItemSelected(_ sender: NSMenuItem) {
        guard let connection = XPCConnection.shared.connection else {
            ViewController.displayWithWindow(text: "Unable to uninstall for broken connection with daemon.", style: .critical)
            return
        }
        
        guard let proxy = connection.remoteObjectProxy as? DaemonXPCProtocol else {
            ViewController.displayWithWindow(text: "Unable to get daemon proxy for uninstallation.", style: .critical)
            return
        }
        
        let confirmView = NSAlert()
        confirmView.alertStyle = .informational
        confirmView.messageText = "Confirm"
        confirmView.informativeText = "Are you sure to uninstall NuwaClient?"
        confirmView.addButton(withTitle: "NO")
        confirmView.addButton(withTitle: "YES")
        let result = confirmView.runModal()
        
        if result == .alertSecondButtonReturn {
            proxy.launchUninstaller()
        }
    }
}

extension ViewController {
    func establishConnection() {
        XPCConnection.shared.connectToDaemon(delegate: self) { success in
            DispatchQueue.main.async { [self] in
                if !success {
                    controlButton.isEnabled = false
                    configMenuStatus(start: false, stop: false)
                    ViewController.displayWithWindow(text: "Unable to start monitoring for broken connection with daemon.", style: .critical)
                } else {
                    Logger(.Info, "Connect to daemon successfully.")
                }
            }
        }
    }
    
    func initMutePaths() {
        _ = eventProvider!.udpateMuteList(list: userPref.allowExecList, type: .AllowProcExec)
        _ = eventProvider!.udpateMuteList(list: userPref.denyExecList, type: .DenyProcExec)
        _ = eventProvider!.udpateMuteList(list: userPref.filePathsForFileMute, type: .FilterFileByFilePath)
        _ = eventProvider!.udpateMuteList(list: userPref.procPathsForFileMute, type: .FilterFileByProcPath)
    }
    
    func setupDisplayTimer() {
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { [self] _ in
            reloadEventInfo()
            // Only update for specific event types (exclude DisplayAll)
            for index in 1..<DisplayMode.allCases.count {
                DispatchQueue.main.async(flags: .barrier) { [self] in
                    // index-1: 0=Process, 1=File, 2=Network
                    graphView.addPointToLine(CGFloat(eventCount[index]-eventCountCopy[index]), index: index-1)
                    eventCountCopy[index] = eventCount[index]
                }
            }
            graphView.needsDisplay = true
        })
    }
    
    func setupClearTimer() {
        if userPref.clearDuration > 0 {
            clearTimer = Timer.scheduledTimer(withTimeInterval: userPref.clearDuration, repeats: true, block: { [self] _ in
                clearButtonClicked(clearButton)
            })
        }
    }
    
    func setupPrefs() {
        let name = Notification.Name(rawValue: DurationChanged)
        NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { [self] _ in
            if isStarted {
                clearTimer.invalidate()
                setupClearTimer()
            }
        }
    }
    
    func shouldDisplayEvent(event: NuwaEventInfo) -> Bool {
        switch event.eventType {
        case .FileOpen, .FileCreate, .FileDelete, .FileCloseModify, .FileRename:
            if displayMode != .DisplayAll && displayMode != .DisplayFile {
                return false
            }

        case .ProcessCreate, .ProcessExit:
            if displayMode != .DisplayAll && displayMode != .DisplayProcess {
                return false
            }
            
        case .NetAccess, .DNSQuery:
            if displayMode != .DisplayAll && displayMode != .DisplayNetwork {
                return false
            }
            if userPref.procPathsForNetMute.contains(event.procPath) {
                return false
            }
            if event.eventType == .NetAccess {
                guard let remoteIP = event.props[PropRemoteAddr]!.split(separator: " ").first?.lowercased() else {
                    return false
                }
                if userPref.ipAddrsForNetMute.contains(remoteIP) {
                    return false
                }
            }

        default:
            Logger(.Warning, "Unknown event type occured.")
            return false
        }
        
        if !searchText.isEmpty && !event.desc.contains(searchText) {
            return false
        }
        
        return true
    }
    
    func updateEventCount(type: NuwaEventType) {
        switch type {
        case .FileOpen, .FileCreate, .FileDelete, .FileCloseModify, .FileRename:
            eventCount[DisplayMode.DisplayFile.rawValue] += 1
        case .ProcessCreate, .ProcessExit:
            eventCount[DisplayMode.DisplayProcess.rawValue] += 1
        case .NetAccess, .DNSQuery:
            eventCount[DisplayMode.DisplayNetwork.rawValue] += 1
        default:
            break
        }
    }
    
    func reloadEventInfo() {
        let index = eventView.selectedRowIndexes
        eventView.reloadData()
        eventView.selectRowIndexes(index, byExtendingSelection: false)
        if eventView.numberOfRows > 0 && isScrollOn {
            eventView.scrollRowToVisible(eventView.numberOfRows-1)
        }
    }
    
    func refreshDisplayedEvents() {
        eventQueue.async(flags: .barrier) {
            self.displayedItems.removeAll()
        }
        
        for event in reportedItems {
            if shouldDisplayEvent(event: event) {
                eventQueue.async(flags: .barrier) {
                    self.displayedItems.append(event)
                }
            }
        }
        reloadEventInfo()
        infoLabel.stringValue = ""
    }
    
    func configMenuStatus(start: Bool, stop: Bool) {
        guard let app = NSApplication.shared.delegate as? AppDelegate else {
            return
        }
        app.setMenuStatus(start: start, stop: stop)
    }
}

extension ViewController: ClientXPCProtocol {
    func connectionDidInterrupt() {
        DispatchQueue.main.async { [self] in
            controlButton.isEnabled = false
            configMenuStatus(start: false, stop: false)
            ViewController.displayWithWindow(text: "Connection to daemon was interrupted.", style: .critical)
        }
    }
    
    func connectionDidInvalidate() {
        DispatchQueue.main.async { [self] in
            controlButton.isEnabled = false
            configMenuStatus(start: false, stop: false)
            ViewController.displayWithWindow(text: "Connection to daemon was invalidated.", style: .critical)
        }
    }
}
