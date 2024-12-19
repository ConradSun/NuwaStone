//
//  NuwaEvents.swift
//  NuwaStone
//
//  Created by ConradSun on 2022/7/14.
//

import Foundation
import AppKit

/// Protocol types for network event
enum NuwaProtocolType: String {
    case Unsupport
    case Tcp
    case Udp
}

/// Event types now supported to monitor
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

/// Mute types now supported to filter
enum NuwaMuteType: UInt8 {
    case TypeNil
    case FilterFileByFilePath
    case FilterFileByProcPath
    case FilterNetByProcPath
    case FilterNetByIPAddr
    case AllowProcExec
    case DenyProcExec
}

/// Protocol for reporting event processing, usually displaying and authorize repling
protocol NuwaEventProcessProtocol {
    func displayNotifyEvent(_ event: NuwaEventInfo)
    func processAuthEvent(_ event: NuwaEventInfo)
    func handleBrokenConnection()
}

/// Protocol for event provider, now supported kext and sext providers
protocol NuwaEventProviderProtocol {
    var processDelegate: NuwaEventProcessProtocol? { get set }
    var isExtConnected: Bool { get }
    func startProvider() -> Bool
    func stopProvider() -> Bool
    func setLogLevel(level: UInt8) -> Bool
    func replyAuthEvent(eventID: UInt64, isAllowed: Bool) -> Bool
    func udpateMuteList(list: [String], type: NuwaMuteType) -> Bool
}

/// Event info for sext reporting and NuwaClient displaying
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
        Properties: \(props)
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
    
    /// Called to set user name with uid
    /// - Parameter uid: user ID, e.g. 0 is uid for root
    func setUserName(uid: uid_t) {
        if NuwaEventInfo.userName[uid] == nil {
            NuwaEventInfo.userName[uid] = getNameFromUid(uid)
        }
        user = NuwaEventInfo.userName[uid]!
    }
    
    /// Called to get code signature for the main process
    func fillCodeSign() {
        let semaphore = DispatchSemaphore(value: 0)
        var signInfo: [String] = []
        
        DispatchQueue.global(qos: .userInitiated).async {
            signInfo = getSignInfoFromPath(self.procPath)
            semaphore.signal()
        }
        
        let timeout = semaphore.wait(timeout: .now() + 3)
        if timeout == .timedOut {
            Logger(.Warning, "Operation timed out while getting code sign for path [\(procPath)].")
            return
        }
        
        if signInfo.count > 0 {
            props[PropCodeSign] = signInfo[0]
        }
    }
    
    /// Called to get bundle identifier for the main process
    func fillBundleIdentifier() {
        props[PropBundleID] = NSRunningApplication.init(processIdentifier: pid)?.bundleIdentifier
    }
    
    /// Called to convert sockaddr to ip:port address
    /// - Parameters:
    ///   - socketAddr: Socket addr to be converted
    ///   - isLocal: Whether addr is local or remote
    func convertSocketAddr(socketAddr: UnsafeMutablePointer<sockaddr>, isLocal: Bool) {
        var ip = [CChar](repeating: 0x0, count: MaxIPLength)
        let data0 = UInt8(bitPattern: socketAddr.pointee.sa_data.0)
        let data1 = UInt8(bitPattern: socketAddr.pointee.sa_data.1)
        let port = (UInt16(data0) << 8) | UInt16(data1)
        inet_ntop(Int32(socketAddr.pointee.sa_family), &socketAddr.pointee.sa_data.2, &ip, socklen_t(MaxIPLength))
        if isLocal {
            props.updateValue("\(String(cString: ip)):\(port)", forKey: PropLocalAddr)
        } else {
            props.updateValue("\(String(cString: ip)):\(port)", forKey: PropRemoteAddr)
        }
    }
    
    /// Called to get parent pid for the main process
    /// - Parameter errorHandler: Code block to process error
    func fillProcPpid(errorHandler: @escaping (Int32) -> Void) {
        getProcPpid(pid: pid) { ppid, error in
            if error != 0 {
                errorHandler(error)
                return
            }
            self.ppid = ppid
        }
    }
    
    /// Called to get process path for the main process
    /// - Parameter errorHandler: Code block to process error
    func fillProcPath(errorHandler: @escaping (Int32) -> Void) {
        getProcPath(pid: pid, eventHandler: { path, error in
            if error != 0 {
                errorHandler(error)
                return
            }
            self.procPath = path
        })
    }
    
    /// Called to get current working directory for the main process
    /// - Parameter errorHandler: Code block to process error
    func fillProcCurrentDir(errorHandler: @escaping (Int32) -> Void) {
        getProcCurrentDir(pid: pid, eventHandler: { cwd, error in
            if error != 0 {
                errorHandler(error)
                return
            }
            self.procCWD = cwd
        })
    }
    
    
    /// Called to get arguments for the main process
    /// - Parameter errorHandler: Code block to process error
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
