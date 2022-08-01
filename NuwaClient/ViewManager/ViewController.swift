//
//  ViewController.swift
//  NuwaClient
//
//  Created by ConradSun on 2022/7/9.
//

import Cocoa

enum DisplayMode : Int {
    case DisplayAll
    case DisplayProcess
    case DisplayFile
    case DisplayNetwork
    
    static var count: Int {
        return DisplayNetwork.rawValue + 1
    }
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
    var isStarted = false
    var isScrollOn = true
    var isInfoOn = true
    var displayMode: DisplayMode = .DisplayAll
    var displayTimer = Timer()
    
    let eventQueue = DispatchQueue(label: "com.nuwastone.eventview.queue")
    var eventCount = Array<UInt32>(repeating: 0, count: DisplayMode.count)
    var eventCountCopy = Array<UInt32>(repeating: 0, count: DisplayMode.count)
    var reportedItems = Array<NuwaEventInfo>()
    var displayedItems = Array<NuwaEventInfo>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        eventView.delegate = self
        eventView.dataSource = self
        eventView.target = self
        kextManager.delegate = self
        
        displayTimer = Timer(timeInterval: 1.0, repeats: true) { [self] timer in
            if (!isStarted) {
                return
            }
            
            self.reloadEventInfo()
            for index in 0..<DisplayMode.count {
                graphView.addPointToLine(CGFloat(eventCount[index]-eventCountCopy[index]), type: DisplayMode(rawValue: index)!)
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
            if !kextManager.startMonitoring() {
                Logger(.Error, "Failed to load kext.")
                return
            }
            kextManager.listenRequestsForType(type: kQueueTypeAuth.rawValue)
            kextManager.listenRequestsForType(type: kQueueTypeNotify.rawValue)
            
            controlButton.image = NSImage(named: "stop")
            controlLabel.stringValue = "stop"
        }
        else {
            if !kextManager.stopMonitoring() {
                Logger(.Error, "Failed to unload kext.")
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
            displayedItems.removeAll()
            displayMode = DisplayMode(rawValue: displaySegment.selectedSegment) ?? .DisplayAll
            refreshDisplayedEvents()
        }
    }
}

extension ViewController {
    func establishConnection() {
        XPCConnection.sharedInstance.connectToDaemon(bundle: Bundle.main, delegate: self) { success in
            DispatchQueue.main.async {
                if !success {
                    self.controlButton.isEnabled = false
                    self.infoLabel.stringValue = "Unable to start monitoring for broken connection with daemon."
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
        if displayMode == .DisplayAll {
            displayedItems = reportedItems
            return
        }
        
        for event in reportedItems {
            switch displayMode {
            case .DisplayProcess:
                if event.eventType == .ProcessCreate || event.eventType == .ProcessExit {
                    displayedItems.append(event)
                }
            case .DisplayFile:
                if event.eventType == .FileDelete || event.eventType == .FileRename || event.eventType == .FileCloseModify || event.eventType == .FileCreate {
                    displayedItems.append(event)
                }
            case .DisplayNetwork:
                break
            default:
                break
            }
        }
        reloadEventInfo()
        infoLabel.stringValue = ""
    }
}

extension ViewController: ClientXPCProtocol {
    
}
