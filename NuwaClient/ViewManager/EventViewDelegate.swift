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

            switch event.eventType {
            case .FileCreate, .FileDelete, .FileCloseModify, .FileRename:
                eventCount[DisplayMode.DisplayFile.rawValue] += 1
                if displayMode != .DisplayAll && displayMode != .DisplayFile {
                    return
                }

            case .ProcessCreate, .ProcessExit:
                eventCount[DisplayMode.DisplayProcess.rawValue] += 1
                if displayMode != .DisplayAll && displayMode != .DisplayProcess {
                    return
                }
                
            case .NetAccess, .DNSQuery:
                if PrefPathList.shared.filterNetworkList.contains(event.procPath) {
                    return
                }
                eventCount[DisplayMode.DisplayNetwork.rawValue] += 1
                if displayMode != .DisplayAll && displayMode != .DisplayNetwork {
                    return
                }

            default:
                Logger(.Warning, "Unknown event type occured.")
                return
            }
            if searchText.isEmpty || event.desc.contains(searchText) {
                eventQueue.async(flags: .barrier) {
                    self.displayedItems.append(event)
                }
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
        if eventView.selectedRowIndexes.count == 0 || eventView.selectedRow > displayedItems.count {
            return
        }
        infoLabel.stringValue = displayedItems[eventView.selectedRow].desc
    }
}

extension ViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return eventQueue.sync {
            displayedItems.count
        }
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var itemCount = 0
        var text = ""
        var event = NuwaEventInfo()
        let format = DateFormatter()
        eventQueue.sync {
            itemCount = self.displayedItems.count
            if row < itemCount {
                event = self.displayedItems[row]
            }
        }
        
        if eventView.numberOfRows == 0 || row >= eventView.numberOfRows || row >= itemCount {
            return nil
        }
        format.dateFormat = "MM-dd HH:mm:ss"
        format.timeZone = .current
        guard let identity = tableColumn?.identifier else {
            return nil
        }
        
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
