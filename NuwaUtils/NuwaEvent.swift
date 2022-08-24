//
//  NuwaEvents.swift
//  NuwaStone
//
//  Created by ConradSun on 2022/7/14.
//

import Foundation
import AppKit

enum NuwaEventType: String, Codable {
    case TypeNil
    case FileCreate
    case FileDelete
    case FileCloseModify
    case FileRename
    case ProcessCreate
    case ProcessExit
    case NetAccess
    case DNSQuery
}

protocol NuwaEventProcessProtocol {
    func displayNotifyEvent(_ event: NuwaEventInfo)
    func processAuthEvent(_ event: NuwaEventInfo)
    func handleBrokenConnection()
}

protocol NuwaEventProviderProtocol {
    var processDelegate: NuwaEventProcessProtocol? { get set }
    func startProvider() -> Bool
    func stopProvider() -> Bool
    func setLogLevel(level: UInt8) -> Bool
    func replyAuthEvent(eventID: UInt64, isAllowed: Bool) -> Bool
    func addProcessToList(path: String?, vnodeID: UInt64, isWhite: Bool) -> Bool
}

class NuwaEventInfo: Codable {
    static var userName = [UInt32(0): "root"]
    var eventID: UInt64
    var eventType: NuwaEventType
    var eventTime: UInt64
    var pid: Int32
    var ppid: Int32
    var user: String
    var procPath: String
    var procCWD: String
    var procArgs: [String]
    var props: [String: String]
    
    var desc: String {
        let pretty = """
        User: \(user)
        Timestamp: \(eventTime)
        Event Type: \(eventType)
        Pid: \(pid) (Parent) -> \(ppid)
        Process Path: \(procPath)
        Current Directory: \(procCWD)
        Process Arguments: \(procArgs)
        Properties:
        \(props as AnyObject)
        """
        return pretty
    }
    
    init() {
        eventID = 0
        eventType = .TypeNil
        eventTime = 0
        pid = 0
        ppid = 0
        user = ""
        procPath = ""
        procCWD = ""
        procArgs = [String]()
        props = [String: String]()
    }
    
    func setUserName(uid: uid_t) {
        if NuwaEventInfo.userName[uid] == nil {
            NuwaEventInfo.userName[uid] = getNameFromUid(uid)
        }
        user = NuwaEventInfo.userName[uid]!
    }
    
    func fillCodeSign() {
        let signInfo = getSignInfoFromPath(procPath)
        if signInfo.count > 0 {
            props[PropCodeSign] = signInfo[0]
        }
    }
    
    func fillBundleIdentifier() {
        props[PropBundleID] = NSRunningApplication.init(processIdentifier: pid)?.bundleIdentifier
    }
    
    func convertSocketAddr(socketAddr: UnsafeMutablePointer<sockaddr>, isLocal: Bool) {
        var ip = [CChar](repeating: 0x0, count: MaxIPLength)
        let data0 = UInt8(bitPattern: socketAddr.pointee.sa_data.0)
        let data1 = UInt8(bitPattern: socketAddr.pointee.sa_data.1)
        let port = (UInt16(data0) << 8) | UInt16(data1)
        inet_ntop(Int32(socketAddr.pointee.sa_family), &socketAddr.pointee.sa_data.2, &ip, socklen_t(MaxIPLength))
        if isLocal {
            props.updateValue("\(String(cString: ip)) : \(port)", forKey: "local")
        }
        else {
            props.updateValue("\(String(cString: ip)) : \(port)", forKey: "remote")
        }
    }
    
    func fillProcPath(errorHandler: @escaping (Int32) -> Void) {
        getProcPath(pid: pid, eventHandler: { path, error in
            if error != 0 {
                errorHandler(error)
                return
            }
            self.procPath = path
        })
    }
    
    func fillProcCurrentDir(errorHandler: @escaping (Int32) -> Void) {
        getProcCurrentDir(pid: pid, eventHandler: { cwd, error in
            if error != 0 {
                errorHandler(error)
                return
            }
            self.procCWD = cwd
        })
    }
    
    func fillProcArgs(errorHandler: @escaping (Int32) -> Void) {
        getProcArgs(pid: pid) { args, error in
            if error != 0 {
                errorHandler(error)
                return
            }
            self.procArgs = args
        }
    }
}
