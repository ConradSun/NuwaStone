//
//  KextManager.swift
//  NuwaClient
//
//  Created by ConradSun on 2022/7/9.
//

import IOKit
import Foundation

class KextManager {
    private var notificationPort: IONotificationPortRef?
    private let authEventQueue = DispatchQueue(label: "com.nuwastone.client.authqueue")
    private let notifyEventQueue = DispatchQueue(label: "com.nuwastone.client.notifyqueue")
    private lazy var proxy = XPCConnection.shared.connection?.remoteObjectProxy as? DaemonXPCProtocol
    static let shared = KextManager()
    var connection: io_connect_t = 0
    var isConnected = false
    var userPref = Preferences()
    var delegate: NuwaEventProcessProtocol?
    
    private func processConnectionRequest(iterator: io_iterator_t) {
        repeat {
            let nextService = IOIteratorNext(iterator)
            guard nextService != 0 else {
                break
            }
            
            var result = IOServiceOpen(nextService, mach_task_self_, 0, &connection)
            if result != kIOReturnSuccess {
                Logger(.Error, "Failed to open kext service [\(String.init(format: "0x%x", result))].")
                IOObjectRelease(nextService)
                break
            }
            
            result = IOConnectCallScalarMethod(connection, kNuwaUserClientOpen.rawValue, nil, 0, nil, nil)
            if result != kIOReturnSuccess {
                Logger(.Error, "An error occurred while opening the connection [\(result)].")
                IOObjectRelease(nextService)
                break
            }
            
            IOObjectRelease(nextService)
            IONotificationPortDestroy(notificationPort)
            isConnected = true
            Logger(.Info, "Connected with kext successfully.")
        } while true
    }
    
    private func waitForDriver(matchingDict: CFDictionary) {
        var iterator: io_iterator_t = 0
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        let notificationQueue = DispatchQueue(label: "com.nuwastone.waitfordriver")
        
        let appearedCallback: IOServiceMatchingCallback = { refcon, iterator in
            let selfPtr = Unmanaged<KextManager>.fromOpaque(refcon!).takeUnretainedValue()
            selfPtr.processConnectionRequest(iterator: iterator)
        }
        
        notificationPort = IONotificationPortCreate(kIOMasterPortDefault)
        IONotificationPortSetDispatchQueue(notificationPort, notificationQueue)
        IOServiceAddMatchingNotification(notificationPort, kIOMatchedNotification, matchingDict, appearedCallback, selfPointer, &iterator)
        processConnectionRequest(iterator: iterator)
    }
    
    private func processKextRequests(type: UInt32, address: mach_vm_address_t, recvPort: mach_port_t) {
        let queueMemory = UnsafeMutablePointer<IODataQueueMemory>.init(bitPattern: UInt(address))
        
        repeat {
            var dataSize = UInt32(MemoryLayout<NuwaKextEvent>.size)
            while IODataQueueDataAvailable(queueMemory) {
                var kextEvent = NuwaKextEvent()
                let result = IODataQueueDequeue(queueMemory, &kextEvent, &dataSize)
                if result != kIOReturnSuccess {
                    Logger(.Error, "Failed to dequeue data [\(String.init(format: "0x%x", result))].")
                    return
                }
                
                switch type {
                case kQueueTypeAuth.rawValue:
                    authEventQueue.async {
                        self.processAuthEvent(&kextEvent)
                    }
                case kQueueTypeNotify.rawValue:
                    notifyEventQueue.async {
                        self.processNotifyEvent(&kextEvent)
                    }
                default:
                    break
                }
            }
            
            if IODataQueueWaitForAvailableData(queueMemory, recvPort) != kIOReturnSuccess {
                Logger(.Error, "Failed to wait for data available.")
                return
            }
        } while isConnected
    }
    
    func listenRequestsForType(type: UInt32) {
        while !isConnected {
            usleep(1000000)
        }
        
        DispatchQueue.global().async {
            let recvPort = IODataQueueAllocateNotificationPort()
            if recvPort == MACH_PORT_NULL {
                Logger(.Error, "Failed to allocate notification port.")
                return
            }
            var result = IOConnectSetNotificationPort(self.connection, type, recvPort, 0)
            if result != kIOReturnSuccess {
                Logger(.Error, "Failed to register notification port [\(String.init(format: "0x%x", result))].")
                mach_port_deallocate(mach_task_self_, recvPort)
                return
            }
            
            var address: mach_vm_address_t = 0
            var size: mach_vm_size_t = 0
            result = IOConnectMapMemory(self.connection, type, mach_task_self_, &address, &size, kIOMapAnywhere)
            if result != kIOReturnSuccess {
                Logger(.Error, "Failed to map memory [\(String.init(format: "0x%x", result))].")
                mach_port_deallocate(mach_task_self_, recvPort)
                return
            }
            
            self.processKextRequests(type: type, address: address, recvPort: recvPort)
            IOConnectUnmapMemory(self.connection, type, mach_task_self_, address)
            mach_port_deallocate(mach_task_self_, recvPort)
        }
    }
}

extension KextManager {
    private func getString<T>(tuple: T) -> String {
        let pathStr = withUnsafePointer(to: tuple) { pointer in
            pointer.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout.size(ofValue: pointer)) { ptr in
                String(cString: ptr)
            }
        }
        
        return pathStr
    }
    
    func processAuthEvent(_ event: inout NuwaKextEvent) {
        let nuwaEvent = NuwaEventInfo()
        nuwaEvent.eventID = event.vnodeID
        nuwaEvent.eventType = .ProcessCreate
        nuwaEvent.eventTime = event.eventTime
        nuwaEvent.pid = event.mainProcess.pid
        nuwaEvent.ppid = event.mainProcess.ppid
        nuwaEvent.procPath = getString(tuple: event.processCreate.path)
        nuwaEvent.fillBundleIdentifier()
        nuwaEvent.fillCodeSign()
        
        // Only the ProcessCreate event is auth type for now.
        if nuwaEvent.props[PropCodeSign] != nil {
            _ = replyAuthEvent(eventID: event.vnodeID, isAllowed: true)
            return
        }
        
        if userPref.auditSwitch {
            delegate?.processAuthEvent(nuwaEvent)
        } else {
            _ = replyAuthEvent(eventID: nuwaEvent.eventID, isAllowed: true)
        }
    }
    
    func processNotifyEvent(_ event: inout NuwaKextEvent) {
        var nuwaEvent = NuwaEventInfo()
        
        switch event.eventType {
        case kActionNotifyProcessCreate:
            nuwaEvent.eventType = .ProcessCreate
            nuwaEvent.procPath = getString(tuple: event.processCreate.path)
        case kActionNotifyFileOpen:
            nuwaEvent.eventType = .FileOpen
            nuwaEvent.props[PropFilePath] = getString(tuple: event.fileOpen.path)
        case kActionNotifyFileCloseModify:
            nuwaEvent.eventType = .FileCloseModify
            nuwaEvent.props[PropFilePath] = getString(tuple: event.fileCloseModify.path)
        case kActionNotifyFileRename:
            nuwaEvent.eventType = .FileRename
            nuwaEvent.props[PropSrcPath] = getString(tuple: event.fileRename.srcFile.path)
            nuwaEvent.props[PropDstPath] = getString(tuple: event.fileRename.newPath)
        case kActionNotifyFileDelete:
            nuwaEvent.eventType = .FileDelete
            nuwaEvent.props[PropFilePath] = getString(tuple: event.fileDelete.path)
        case kActionNotifyNetworkAccess:
            nuwaEvent.eventType = .NetAccess
            nuwaEvent.convertSocketAddr(socketAddr: &event.netAccess.localAddr, isLocal: true)
            nuwaEvent.convertSocketAddr(socketAddr: &event.netAccess.remoteAddr, isLocal: false)
            if event.netAccess.protocol == IPPROTO_TCP {
                nuwaEvent.props[PropProtocol] = NuwaProtocolType.Tcp.rawValue
            } else if event.netAccess.protocol == IPPROTO_UDP {
                nuwaEvent.props[PropProtocol] = NuwaProtocolType.Udp.rawValue
            } else {
                nuwaEvent.props[PropProtocol] = NuwaProtocolType.Unsupport.rawValue
            }
        case kActionNotifyDnsQuery:
            nuwaEvent.eventType = .DNSQuery
            nuwaEvent.props[PropDomainName] = getString(tuple: event.dnsQuery.domainName)
            nuwaEvent.props[PropReplyResult] = getString(tuple: event.dnsQuery.queryResult)
        default:
            break
        }
        
        nuwaEvent.eventTime = event.eventTime
        nuwaEvent.pid = event.mainProcess.pid
        nuwaEvent.ppid = event.mainProcess.ppid
        nuwaEvent.setUserName(uid: event.mainProcess.euid)
        
        if nuwaEvent.eventType == .ProcessCreate {
            nuwaEvent.fillProcCurrentDir { error in
                if error == EPERM {
                    self.proxy?.getProcessCurrentDir(pid: nuwaEvent.pid, eventHandler: { cwd, error in
                        nuwaEvent.procCWD = cwd
                    })
                }
            }
            nuwaEvent.fillProcArgs { error in
                if error == EPERM {
                    self.proxy?.getProcessArgs(pid: nuwaEvent.pid, eventHandler: { args, error in
                        nuwaEvent.procArgs = args
                    })
                }
            }
            nuwaEvent.fillBundleIdentifier()
            nuwaEvent.fillCodeSign()
            ProcessCache.shared.updateCache(nuwaEvent)
        } else {
            ProcessCache.shared.getFromCache(&nuwaEvent)
        }
        
        delegate?.displayNotifyEvent(nuwaEvent)
    }
}

extension KextManager: NuwaEventProviderProtocol {
    var processDelegate: NuwaEventProcessProtocol? {
        get {
            return delegate
        }
        set {
            delegate = newValue
        }
    }
    
    var isExtConnected: Bool {
        get {
            return isConnected
        }
    }
    
    func startProvider() -> Bool {
        guard let service = IOServiceMatching(KextService.cString(using: .utf8)) else {
            return false
        }
        
        Logger(.Info, "Wait for kext to be connected.")
        waitForDriver(matchingDict: service)
        
        listenRequestsForType(type: kQueueTypeAuth.rawValue)
        listenRequestsForType(type: kQueueTypeNotify.rawValue)
        return isConnected
    }
    
    func stopProvider() -> Bool {
        let result = IOServiceClose(connection)
        if result != KERN_SUCCESS {
            Logger(.Error, "Failed to close IOService [\(String.init(format: "0x%x", result))].")
            return false
        }
        
        connection = IO_OBJECT_NULL
        isConnected = false
        return true
    }
    
    func setLogLevel(level: NuwaLogLevel) -> Bool {
        let scalar: [UInt64] = [UInt64(level.rawValue)]
        let result = IOConnectCallScalarMethod(connection, kNuwaUserClientSetLogLevel.rawValue, scalar, 1, nil, nil)
        NuwaLog.logLevel = level
        if result != KERN_SUCCESS {
            Logger(.Error, "Failed to set log level for kext [\(String.init(format: "0x%x", result))].")
            return false
        }
        Logger(.Info, "Log level is setted to \(NuwaLog.logLevel)")
        return true
    }
    
    func replyAuthEvent(eventID: UInt64, isAllowed: Bool) -> Bool {
        guard eventID != 0 else {
            Logger(.Warning, "Invalid ID for auth event.")
            return false
        }
        
        let scalar = [eventID]
        var result = KERN_SUCCESS
        if isAllowed {
            result = IOConnectCallScalarMethod(connection, kNuwaUserClientAllowBinary.rawValue, scalar, 1, nil, nil)
        } else {
            result = IOConnectCallScalarMethod(connection, kNuwaUserClientDenyBinary.rawValue, scalar, 1, nil, nil)
        }
        if result != KERN_SUCCESS {
            Logger(.Error, "Failed to reply auth event [\(String.init(format: "0x%x", result))].")
            return false
        }
        return true
    }
    
    func udpateMuteList(list: [String], type: NuwaMuteType) -> Bool {
        var result = KERN_SUCCESS
        var muteInfo = NuwaKextMuteInfo()
        muteInfo.muteType.rawValue = UInt32(type.rawValue)
        withUnsafeMutablePointer(to: &muteInfo.vnodeIDs) { pointer in
            let vnodePtr = UnsafeMutableRawPointer(pointer).assumingMemoryBound(to: UInt64.self)
            for i in 0 ..< list.count {
                if i >= kMaxCacheItems {
                    break
                }
                vnodePtr[i] = getFileVnodeID(list[i])
            }
        }
        
        result = IOConnectCallStructMethod(connection, kNuwaUserClientUpdateMuteList.rawValue, &muteInfo, MemoryLayout<NuwaKextMuteInfo>.size, nil, nil)
        if result != KERN_SUCCESS {
            Logger(.Error, "Failed to add mute info to list [\(String.init(format: "0x%x", result))].")
            return false
        }
        return true
    }
}
