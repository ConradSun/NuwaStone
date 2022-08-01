//
//  EventViewDelegate.swift
//  NuwaClient
//
//  Created by ConradSun on 2022/7/20.
//

import Cocoa

extension ViewController: NuwaEventProtocol {
    func displayNuwaEvent(_ event: NuwaEventInfo) {
        eventQueue.sync {
            reportedItems.append(event)
            eventCount[DisplayMode.DisplayAll.rawValue] += 1

            switch event.eventType {
            case .FileCreate:
                fallthrough
            case .FileDelete:
                fallthrough
            case .FileCloseModify:
                fallthrough
            case .FileRename:
                eventCount[DisplayMode.DisplayFile.rawValue] += 1
                if displayMode == .DisplayAll || displayMode == .DisplayFile {
                    displayedItems.append(event)
                }

            case .ProcessCreate:
                fallthrough
            case .ProcessExit:
                eventCount[DisplayMode.DisplayProcess.rawValue] += 1
                if displayMode == .DisplayAll || displayMode == .DisplayProcess {
                    displayedItems.append(event)
                }
            default:
                Logger(.Warning, "Unknown event type occured.")
                break
            }
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
        return displayedItems.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if eventView.numberOfRows == 0 || row >= eventView.numberOfRows || row >= displayedItems.count {
            return nil
        }
        
        var text = ""
        let event = displayedItems[row]
        let format = DateFormatter()
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
