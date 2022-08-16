//
//  ViewController.swift
//  NuwaClient
//
//  Created by ConradSun on 2022/7/9.
//

import Cocoa

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
    
    let kextManager = KextManager()
    let sextManager = SextManager()
    
    var isStarted = false
    var isScrollOn = true
    var isInfoOn = true
    var searchText = ""
    var displayMode = DisplayMode.DisplayAll
    var displayTimer = Timer()
    
    let eventQueue = DispatchQueue(label: "com.nuwastone.eventview.queue")
    var eventCount = [UInt32](repeating: 0, count: DisplayMode.allCases.count)
    var eventCountCopy = [UInt32](repeating: 0, count: DisplayMode.allCases.count)
    var reportedItems = [NuwaEventInfo]()
    var displayedItems = [NuwaEventInfo]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        kextManager.delegate = self
        sextManager.delegate = self;
        
        eventView.delegate = self
        eventView.dataSource = self
        eventView.target = self
        
        displayTimer = Timer(timeInterval: 1.0, repeats: true) { [self] timer in
            if (!isStarted) {
                return
            }
            
            self.reloadEventInfo()
            for (index, _) in DisplayMode.allCases.enumerated() {
                graphView.addPointToLine(CGFloat(eventCount[index]-eventCountCopy[index]), index: index)
                eventCountCopy[index] = eventCount[index]
            }
            graphView.draw(graphView.frame)
            graphView.needsDisplay = true
        }
        RunLoop.current.add(displayTimer, forMode: .default)
        displayTimer.fire()
        
        establishConnection()
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    @IBAction func controlButtonClicked(_ sender: Any) {
        isStarted = !isStarted
        if isStarted {
            if #available(macOS 10.16, *) {
                if !sextManager.startMonitoring() {
                    alertWithError(error: "Failed to connect sext.")
                    return
                }
            }
            else {
                if !kextManager.startMonitoring() {
                    alertWithError(error: "Failed to connect kext.")
                    return
                }
                kextManager.listenRequestsForType(type: kQueueTypeAuth.rawValue)
                kextManager.listenRequestsForType(type: kQueueTypeNotify.rawValue)
            }
            
            ProcessCache.sharedInstance.initProcCache();
            controlButton.image = NSImage(named: "stop")
            controlLabel.stringValue = "stop"
        }
        else {
            if #available(macOS 10.16, *) {
                if !sextManager.stopMonitoring() {
                    alertWithError(error: "Failed to disconnect sext.")
                }
            }
            else {
                if !kextManager.stopMonitoring() {
                    alertWithError(error: "Failed to disconnect kext.")
                }
            }
            
            controlButton.image = NSImage(named: "start")
            controlLabel.stringValue = "start"
        }
    }
    
    @IBAction func scrollButtonClicked(_ sender: Any) {
        isScrollOn = !isScrollOn
        if isScrollOn {
            scrollButton.image = NSImage(named: "scroll-on")
        }
        else {
            scrollButton.image = NSImage(named: "scroll-off")
        }
    }
    
    @IBAction func clearButtonClicked(_ sender: Any) {
        reportedItems.removeAll()
        displayedItems.removeAll()
        reloadEventInfo()
        infoLabel.stringValue = ""
    }
    
    @IBAction func infoButtonClicked(_ sender: Any) {
        isInfoOn = !isInfoOn
        if isInfoOn {
            InfoButton.image = NSImage(named: "show-on")
            splitView.arrangedSubviews[1].isHidden = false
        }
        else {
            infoLabel.stringValue = ""
            InfoButton.image = NSImage(named: "show-off")
            splitView.arrangedSubviews[1].isHidden = true
        }
    }
    
    @IBAction func displaySegmentValueChanged(_ sender: Any) {
        if displaySegment.selectedSegment != displayMode.rawValue {
            displayMode = DisplayMode(rawValue: displaySegment.selectedSegment) ?? .DisplayAll
            refreshDisplayedEvents()
        }
    }
    
    @IBAction func searchBarTextModified(_ sender: Any) {
        searchText = searchBar.stringValue
        refreshDisplayedEvents()
    }
}

extension ViewController {
    func alertWithError(error: String) {
        let alert = NSAlert()
        Logger(.Error, error)
        alert.informativeText = error
        alert.alertStyle = .critical
        alert.messageText = "Error"
        alert.runModal()
    }
    
    func establishConnection() {
        XPCConnection.sharedInstance.connectToDaemon(bundle: Bundle.main, delegate: self) { success in
            DispatchQueue.main.async {
                if !success {
                    self.controlButton.isEnabled = false
                    self.alertWithError(error: "Unable to start monitoring for broken connection with daemon.")
                }
            }
        }
    }
    
    func reloadEventInfo() {
        let index = IndexSet(integer: eventView.selectedRow)
        eventView.reloadData()
        eventView.selectRowIndexes(index, byExtendingSelection: false)
        if eventView.numberOfRows > 0 && isScrollOn {
            eventView.scrollRowToVisible(eventView.numberOfRows-1)
        }
    }
    
    func refreshDisplayedEvents() {
        displayedItems.removeAll()
        if displayMode == .DisplayAll && searchText.isEmpty {
            displayedItems = reportedItems
            return
        }
        
        for event in reportedItems {
            switch displayMode {
            case .DisplayAll:
                ()
            case .DisplayProcess:
                if event.eventType != .ProcessCreate && event.eventType != .ProcessExit {
                    continue
                }
            case .DisplayFile:
                if event.eventType != .FileDelete && event.eventType != .FileRename && event.eventType != .FileCloseModify && event.eventType != .FileCreate {
                    continue
                }
            case .DisplayNetwork:
                if event.eventType != .NetAccess && event.eventType != .DNSQuery {
                    continue
                }
            }
            if searchText.isEmpty || event.desc.contains(searchText) {
                displayedItems.append(event)
            }
        }
        reloadEventInfo()
        infoLabel.stringValue = ""
    } 
}

extension ViewController: ClientXPCProtocol {
    
}
