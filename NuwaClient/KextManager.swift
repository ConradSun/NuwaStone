//
//  KextManager.swift
//  NuwaClient
//
//  Created by 孙康 on 2022/7/9.
//

import IOKit
import IOKit.kext
import Foundation

class KextManager {
    enum Event {
        case Connect
        case Disconnect
    }
    
    private let notificationPort = IONotificationPortCreate(kIOMasterPortDefault)
    private let kextID = CFStringCreateWithCString(kCFAllocatorDefault, kDriverIdentifier, kCFStringEncodingASCII)
    private let authEventQueue = DispatchQueue.global()
    var connection: io_connect_t = 0
    var isConnected: Bool = false
    var nuwaLog = NuwaLog()
    
    private func dispatchServiceEvent(for event: Event, iterator: io_iterator_t) {
        repeat {
            let nextService = IOIteratorNext(iterator)
            guard nextService != 0 else {
                break
            }
            switch event {
            case .Connect:
                var result = IOServiceOpen(nextService, mach_task_self_, 0, &self.connection)
                if result != kIOReturnSuccess {
                    Logger(.Error, "Failed to open kext service [\(String.init(format: "0x%x", result))].")
                    break
                }
                
                result = IOConnectCallScalarMethod(self.connection, kNuwaUserClientOpen.rawValue, nil, 0, nil, nil)
                if result == kIOReturnExclusiveAccess {
                    Logger(.Error, "A client is already connected.")
                    break
                }
                else if result != kIOReturnSuccess {
                    Logger(.Error, "An error occurred while opening the connection [\(result)].")
                    break
                }
                
                IONotificationPortDestroy(self.notificationPort)
                self.isConnected = true
                Logger(.Info, "Connected with kext successfully.")
            case .Disconnect:
                break
            }
            IOObjectRelease(nextService)
        } while true
    }
    
    private func waitForDriver(matchingDict: CFDictionary) {
        var iterator: io_iterator_t = 0
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        let notificationQueue = DispatchQueue(label: "com.nuwastone.waitfordriver")
        
        let appearedCallback: IOServiceMatchingCallback = { refcon, iterator in
            let selfPtr = Unmanaged<KextManager>.fromOpaque(refcon!).takeUnretainedValue()
            selfPtr.dispatchServiceEvent(for: .Connect, iterator: iterator)
        };
        
        IONotificationPortSetDispatchQueue(notificationPort, notificationQueue)
        IOServiceAddMatchingNotification(notificationPort, kIOMatchedNotification, matchingDict, appearedCallback, selfPointer, &iterator)
        dispatchServiceEvent(for: .Connect, iterator: iterator)
    }
    
    private func processKextRequests(type: UInt32, address: mach_vm_address_t, recvPort: mach_port_t) {
        let queueMemory = UnsafeMutablePointer<IODataQueueMemory>.init(bitPattern: UInt(address))
        DispatchQueue.global().async {
            repeat {
                while IODataQueueDataAvailable(queueMemory) {
                    var kextEvent = NuwaKextEvent()
                    var dataSize: UInt32 = UInt32(MemoryLayout.size(ofValue: NuwaKextEvent()))
                    let result = IODataQueueDequeue(queueMemory, &kextEvent, &dataSize)
                    if result != kIOReturnSuccess {
                        Logger(.Error, "Failed to dequeue data [\(String.init(format: "0x%x", result))].")
                        break
                    }
                    
                    switch type {
                    case kQueueTypeAuth.rawValue:
                        self.authEventQueue.async {
                            self.processAuthEvent(kextEvent)
                        }
                    default:
                        break
                    }
                }
            } while IODataQueueWaitForAvailableData(queueMemory, recvPort) == kIOReturnSuccess
        }
    }
    
    func loadKernelExtension() -> Bool {
        guard let service = IOServiceMatching(kDriverService) else {
            return false
        }
        
        let result = KextManagerLoadKextWithIdentifier(kextID, nil)
        if result != kIOReturnSuccess {
            Logger(.Warning, "Error occured in loading kext [\(String.init(format: "0x%x", result))].")
            return false
        }
        
        Logger(.Info, "Wait for kext to be connected.")
        waitForDriver(matchingDict: service)
        return true
    }
    
    func unloadKernelExtension() -> Bool {
        IOServiceClose(connection)
        let result = KextManagerUnloadKextWithIdentifier(kextID)
        if result != kIOReturnSuccess {
            Logger(.Warning, "Error occured in unloading kext [\(String.init(format: "0x%x", result))].")
            return false
        }
        return true
    }
    
    func listenRequestsForType(type: UInt32) {
        guard isConnected else {
            return
        }
        
        let recvPort = IODataQueueAllocateNotificationPort()
        if recvPort == MACH_PORT_NULL {
            Logger(.Error, "Failed to allocate notification port.")
            return
        }
        var result = IOConnectSetNotificationPort(connection, type, recvPort, 0)
        if result != kIOReturnSuccess {
            Logger(.Error, "Failed to register notification port [\(String.init(format: "0x%x", result))].")
            mach_port_deallocate(mach_task_self_, recvPort)
            return
        }
        
        var address: mach_vm_address_t = 0
        var size: mach_vm_size_t = 0
        result = IOConnectMapMemory(connection, type, mach_task_self_, &address, &size, kIOMapAnywhere)
        if result != kIOReturnSuccess {
            Logger(.Error, "Failed to map memory [\(String.init(format: "0x%x", result))].")
            mach_port_deallocate(mach_task_self_, recvPort)
            return
        }
        
        processKextRequests(type: type, address: address, recvPort: recvPort)
        IOConnectUnmapMemory(connection, type, mach_task_self_, address)
        mach_port_deallocate(mach_task_self_, recvPort)
    }
}

extension KextManager {
    func processAuthEvent(_ event: NuwaKextEvent) {
        var str = event.processCreate.path
        let procPath = String(cString: &str.0)
        Logger(.Info, "pid [\(String.init(format: "%d", event.mainProcess.pid))], file path [\(procPath)].")
        
        if procPath == "/bin/ls" {
            _ = replyAuthEvent(vnodeID: event.vnodeID, isAllowed: false)
            return
        }
        _ = replyAuthEvent(vnodeID: event.vnodeID, isAllowed: true)
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
    
    func setLogLevel(level: UInt32) -> Bool {
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
