//
//  NuwaEvents.swift
//  NuwaStone
//
//  Created by 孙康 on 2022/7/14.
//

import Foundation

enum NuwaEventType : String {
    case TypeNil
    case FileCreate
    case FileDelete
    case FileOpen
    case FileCloseModify
    case FileRename
    case ProcessCreate
    case ProcessExit
}

struct NuwaEventInfo {
    var eventType: NuwaEventType
    var eventTime: UInt64
    var pid: UInt32
    var ppid: UInt32
    var procPath: String
    
    var props: Dictionary<String, Any>
    var desc: String {
        let pretty = """
        Event Type: \(eventType)
        Timestamp: \(eventTime)
        Pid: \(pid) (Parent) -> \(ppid)
        Process: \(procPath)
        Props:
        \(props as AnyObject)
        """
        return pretty
    }
    
    init() {
        eventType = .TypeNil
        eventTime = 0
        pid = 0
        ppid = 0
        procPath = ""
        props = Dictionary<String, Any>()
    }
}
