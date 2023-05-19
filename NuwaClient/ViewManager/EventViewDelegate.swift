//
//  EventViewDelegate.swift
//  NuwaClient
//
//  Created by ConradSun on 2022/7/20.
//

import Cocoa

extension ViewController: NuwaEventProcessProtocol {
    func displayNotifyEvent(_ event: NuwaEventInfo) {
        eventQueue.async(flags: .barrier) { [self] in
            reportedItems.append(event)
            eventCount[DisplayMode.DisplayAll.rawValue] += 1

            if shouldDisplayEvent(event: event) {
                displayedItems.append(event)
                updateEventCount(type: event.eventType)
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
            alertWithError(error: "Connection with extension is broken.")
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
    func numberOfRows(in tableView: NSTableView) -> Int {
        return eventQueue.sync {
            displayedItems.count
        }
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let itemCount = eventQueue.sync {
            displayedItems.count
        }
        if eventView.numberOfRows == 0 || row >= eventView.numberOfRows || row >= itemCount {
            return nil
        }
        guard let identity = tableColumn?.identifier else {
            return nil
        }
        
        let event = eventQueue.sync {
            displayedItems[row]
        }
        let format = DateFormatter()
        format.dateFormat = "MM-dd HH:mm:ss"
        format.timeZone = .current
        var text = ""
        
        switch tableColumn {
        case eventView.tableColumns[0]:
            let date = Date(timeIntervalSince1970: TimeInterval(event.eventTime))
            text = format.string(from: date)
        case eventView.tableColumns[1]:
            text = String(event.pid)
        case eventView.tableColumns[2]:
            text = String(format: "\(event.eventType)")
        case eventView.tableColumns[3]:
            text = event.procPath
        case eventView.tableColumns[4]:
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
