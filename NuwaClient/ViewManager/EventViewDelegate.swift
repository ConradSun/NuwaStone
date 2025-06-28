//
//  EventViewDelegate.swift
//  NuwaClient
//
//  Created by ConradSun on 2022/7/20.
//

import Cocoa

extension ViewController {
    static func displayWithWindow(text: String, style: NSAlert.Style) {
        let alert = NSAlert()
        alert.informativeText = text
        alert.alertStyle = style
        switch style {
        case .informational:
            alert.messageText = "Info"
        case .warning:
            alert.messageText = "Warning"
        case .critical:
            alert.messageText = "Error"
        @unknown default:
            alert.messageText = "Tips"
        }
        alert.runModal()
    }
}

extension ViewController: NuwaEventProcessProtocol {
    func displayNotifyEvent(_ event: NuwaEventInfo) {
        eventQueue.async(flags: .barrier) { [self] in
            reportedItems.append(event)
            eventCount[DisplayMode.DisplayAll.rawValue] += 1
            updateEventCount(type: event.eventType)

            if shouldDisplayEvent(event: event) {
                displayedItems.append(event)
            }
        }
    }
    
    func processAuthEvent(_ event: NuwaEventInfo) {
        if event.eventType == .ProcessCreate {
            DispatchQueue.main.sync {
                alertWindow = AlertWindowController(windowNibName: "Alert")
                alertWindow!.authEvent = event
                alertWindow!.showWindow(self)
            }
        }
    }
    
    func handleBrokenConnection() {
        DispatchQueue.main.sync {
            controlButtonClicked(controlButton)
            ViewController.displayWithWindow(text: "Connection with extension is broken.", style: .critical)
        }
    }
}

extension ViewController: NSTableViewDelegate {
    func tableViewSelectionDidChange(_ notification: Notification) {
        let count = eventQueue.sync {
            displayedItems.count
        }
        
        if eventView.selectedRowIndexes.count == 0 || eventView.selectedRow > count {
            return
        }
        infoLabel.stringValue = eventQueue.sync {
            displayedItems[eventView.selectedRow].desc
        }
    }
}

extension ViewController: NSTableViewDataSource {
    private static let sharedDateFormatter: DateFormatter = {
        let format = DateFormatter()
        format.dateFormat = "MM-dd HH:mm:ss"
        format.timeZone = .current
        return format
    }()
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return eventQueue.sync {
            displayedItems.count
        }
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let itemCount = eventQueue.sync {
            displayedItems.count
        }
        if row >= itemCount {
            return nil
        }
        guard let identity = tableColumn?.identifier else {
            return nil
        }
        let event = eventQueue.sync {
            displayedItems[row]
        }
        var text = ""
        switch identity.rawValue {
        case "time":
            let date = Date(timeIntervalSince1970: TimeInterval(event.eventTime))
            text = ViewController.sharedDateFormatter.string(from: date)
        case "pid":
            text = String(event.pid)
        case "type":
            text = String(format: "\(event.eventType)")
        case "process":
            text = event.procPath
        case "props":
            text = String(format: "\(event.props)")
        default:
            break
        }
        guard let cell = eventView.makeView(withIdentifier: identity, owner: self) as? NSTableCellView else {
            return nil
        }
        cell.textField?.stringValue = text
        return cell
    }
}
