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
    private let authEventQueue = DispatchQueue(label: "com.nuwastone.auth.queue")
    private let notifyEventQueue = DispatchQueue(label: "com.nuwastone.notify.queue")
    private lazy var proxy = XPCConnection.sharedInstance.connection?.remoteObjectProxy as? DaemonXPCProtocol
    var connection: io_connect_t = 0
    var isConnected: Bool = false
    var nuwaLog = NuwaLog()
    var delegate: NuwaEventProtocol?
    
    private func processConnectionRequest(iterator: io_iterator_t) {
        repeat {
            let nextService = IOIteratorNext(iterator)
            guard nextService != 0 else {
                break
            }
            
            var result = IOServiceOpen(nextService, mach_task_self_, 0, &self.connection)
            if result != kIOReturnSuccess {
                Logger(.Error, "Failed to open kext service [\(String.init(format: "0x%x", result))].")
                IOObjectRelease(nextService)
                break
            }
            
            result = IOConnectCallScalarMethod(self.connection, kNuwaUserClientOpen.rawValue, nil, 0, nil, nil)
            if result != kIOReturnSuccess {
                Logger(.Error, "An error occurred while opening the connection [\(result)].")
                IOObjectRelease(nextService)
                break
            }
            
            IOObjectRelease(nextService)
            IONotificationPortDestroy(notificationPort)
            self.isConnected = true
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
        };
        
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
    
    func startMonitoring() -> Bool {
        guard let service = IOServiceMatching(KextService.cString(using: .utf8)) else {
            return false
        }
        
        Logger(.Info, "Wait for kext to be connected.")
        waitForDriver(matchingDict: service)
        return true
    }
    
    func stopMonitoring() -> Bool {
        let result = IOServiceClose(connection)
        if result != KERN_SUCCESS {
            Logger(.Error, "Failed to close IOService [\(String.init(format: "0x%x", result))].")
            return false
        }
        
        connection = IO_OBJECT_NULL
        isConnected = false
        return true
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
    func processAuthEvent(_ event: inout NuwaKextEvent) {
        let nuwaEvent = NuwaEventInfo()
        nuwaEvent.eventType = .ProcessCreate
        nuwaEvent.eventTime = event.eventTime
        nuwaEvent.pid = event.mainProcess.pid
        nuwaEvent.ppid = event.mainProcess.ppid
        nuwaEvent.procPath = String(cString: &event.processCreate.path.0)
        
        _ = replyAuthEvent(vnodeID: event.vnodeID, isAllowed: true)
    }
    
    func processNotifyEvent(_ event: inout NuwaKextEvent) {
        var nuwaEvent = NuwaEventInfo()
        
        switch event.eventType {
        case kActionNotifyProcessCreate:
            nuwaEvent.eventType = .ProcessCreate
            nuwaEvent.procPath = String(cString: &event.processCreate.path.0)
        case kActionNotifyFileCloseModify:
            nuwaEvent.eventType = .FileCloseModify
            nuwaEvent.props["FilePath"] = String(cString: &event.fileCloseModify.path.0)
        case kActionNotifyFileRename:
            nuwaEvent.eventType = .FileRename
            nuwaEvent.props["from"] = String(cString: &event.fileRename.srcFile.path.0)
            nuwaEvent.props["move to"] = String(cString: &event.fileRename.newPath.0)
        case kActionNotifyFileDelete:
            nuwaEvent.eventType = .FileDelete
            nuwaEvent.props["FilePath"] = String(cString: &event.fileDelete.path.0)
        case kActionNotifyNetworkAccess:
            nuwaEvent.eventType = .NetAccess
            nuwaEvent.convertSocketAddr(socketAddr: &event.netAccess.localAddr, isLocal: true)
            nuwaEvent.convertSocketAddr(socketAddr: &event.netAccess.remoteAddr, isLocal: false)
            if event.netAccess.protocol == IPPROTO_TCP {
                nuwaEvent.props["protocol"] = "tcp"
            }
            else if event.netAccess.protocol == IPPROTO_UDP {
                nuwaEvent.props["protocol"] = "udp"
            }
            else {
                nuwaEvent.props["protocol"] = "unsupport"
            }
        default:
            break
        }
        
        nuwaEvent.eventTime = event.eventTime
        nuwaEvent.pid = event.mainProcess.pid
        nuwaEvent.ppid = event.mainProcess.ppid
        nuwaEvent.setUserName(uid: event.mainProcess.euid)
        
        if nuwaEvent.eventType == .ProcessCreate {
            nuwaEvent.procPath = String(cString: &event.processCreate.path.0)
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
            nuwaEvent.fillCodeSign()
            ProcessCache.sharedInstance.updateCache(nuwaEvent)
        }
        else {
            ProcessCache.sharedInstance.getFromCache(&nuwaEvent)
        }
        
        delegate!.displayNuwaEvent(nuwaEvent)
    }
    
    func replyAuthEvent(vnodeID: UInt64, isAllowed: Bool) -> Bool {
        guard vnodeID != 0 else {
            return false
        }
        
        let scalar = [vnodeID]
        var result = KERN_SUCCESS
        if isAllowed {
            result = IOConnectCallScalarMethod(self.connection, kNuwaUserClientAllowBinary.rawValue, scalar, 1, nil, nil)
        }
        else {
            result = IOConnectCallScalarMethod(self.connection, kNuwaUserClientDenyBinary.rawValue, scalar, 1, nil, nil)
        }
        if result != KERN_SUCCESS {
            Logger(.Error, "Failed to reply auth event [\(String.init(format: "0x%x", result))].")
            return false
        }
        return true
    }
    
    func setLogLevel(level: UInt8) -> Bool {
        nuwaLog.logLevel = level
        let scalar = [UInt64(level)]
        let result = IOConnectCallScalarMethod(self.connection, kNuwaUserClientSetLogLevel.rawValue, scalar, 1, nil, nil)
        if result != KERN_SUCCESS {
            Logger(.Error, "Failed to set log level for kext [\(String.init(format: "0x%x", result))].")
            return false
        }
        return true
    }
}
