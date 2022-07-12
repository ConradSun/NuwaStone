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
    private let kextID = CFStringCreateWithCString(kCFAllocatorDefault, "com.nuwastone", kCFStringEncodingASCII)
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
                    Log(level: NuwaLogLevel.LOG_ERROR, "Failed to open kext service [\(String.init(format: "0x%x", result))].")
                    break
                }
                
                result = IOConnectCallScalarMethod(self.connection, kNuwaUserClientOpen.rawValue, nil, 0, nil, nil)
                if result == kIOReturnExclusiveAccess {
                    Log(level: NuwaLogLevel.LOG_ERROR, "A client is already connected.")
                    break
                }
                else if result != kIOReturnSuccess {
                    Log(level: NuwaLogLevel.LOG_ERROR, "An error occurred while opening the connection [\(result)].")
                    break
                }
                
                IONotificationPortDestroy(self.notificationPort)
                self.isConnected = true
                Log(level: NuwaLogLevel.LOG_INFO, "Connected with kext successfully.")
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
    
    func loadKernelExtension() -> Bool {
        guard let service = IOServiceMatching("DriverService") else {
            return false
        }
        
        let result = KextManagerLoadKextWithIdentifier(kextID, nil)
        if result != kIOReturnSuccess {
            Log(level: NuwaLogLevel.LOG_WARN, "Error occured in loading kext [\(String.init(format: "0x%x", result))].")
            return false
        }
        
        Log(level: NuwaLogLevel.LOG_INFO, "Wait for kext to be connected.")
        waitForDriver(matchingDict: service)
        return true
    }
    
    func unloadKernelExtension() -> Bool {
        IOServiceClose(connection)
        let result = KextManagerUnloadKextWithIdentifier(kextID)
        if result != kIOReturnSuccess {
            Log(level: NuwaLogLevel.LOG_WARN, "Error occured in unloading kext [\(String.init(format: "0x%x", result))].")
            return false
        }
        return true
    }
    
    func setLogLevel(level: UInt32) -> Bool {
        nuwaLog.logLevel = level
        let scalar: [UInt64] = [UInt64(level)]
        let result = IOConnectCallScalarMethod(self.connection, kNuwaUserClientSetLogLevel.rawValue, scalar, 1, nil, nil)
        if result != KERN_SUCCESS {
            Log(level: NuwaLogLevel.LOG_ERROR, "Failed to set log level for kext [\(String.init(format: "0x%x", result))].")
            return false
        }
        return true
    }
}
