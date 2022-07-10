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
    private let notificationPort = IONotificationPortCreate(kIOMasterPortDefault)
    private let kextID = CFStringCreateWithCString(kCFAllocatorDefault, "com.nuwastone", kCFStringEncodingASCII)
    var isConnected: io_connect_t = 0
    
    private func dispatchServiceEvent(for callback: IOServiceMatchingCallback, iterator: io_iterator_t) {
        repeat {
            let selfPointer = Unmanaged.passUnretained(self).toOpaque()
            let nextService = IOIteratorNext(iterator)
            guard nextService != 0 else {
                break
            }
            callback(selfPointer, nextService)
            IOObjectRelease(nextService)
        } while true
    }
    
    private func waitForDriver(matchingDict: CFDictionary) {
        var iterator: io_iterator_t = 0
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        let notificationQueue = DispatchQueue(label: "com.nuwastone.waitfordriver")
        
        let matchCallback: IOServiceMatchingCallback = { refcon, iterator in
            let selfPtr = Unmanaged<KextManager>.fromOpaque(refcon!).takeUnretainedValue()
            var result = IOServiceOpen(iterator, mach_task_self_, 0, &selfPtr.isConnected)
            if result != kIOReturnSuccess {
                Log(level: NuwaLogLevel.LOG_ERROR, "Failed to open kext service [\(result)].")
                return
            }
            
            result = IOConnectCallScalarMethod(selfPtr.isConnected, NuwaKextMethods.kNuwaUserClientOpen.rawValue, nil, 0, nil, nil)
            if result == kIOReturnExclusiveAccess {
                Log(level: NuwaLogLevel.LOG_ERROR, "A client is already connected.")
                return
            }
            else if result != kIOReturnSuccess {
                Log(level: NuwaLogLevel.LOG_ERROR, "An error occurred while opening the connection [\(result)].")
                return
            }
            
            IOObjectRelease(iterator)
            IONotificationPortDestroy(selfPtr.notificationPort)
            selfPtr.isConnected = 1
        };
        
        IONotificationPortSetDispatchQueue(notificationPort, notificationQueue)
        IOServiceAddMatchingNotification(notificationPort, kIOMatchedNotification, matchingDict, matchCallback, selfPointer, &iterator)
        dispatchServiceEvent(for: matchCallback, iterator: iterator)
    }
    
    func loadKernelExtension() {
        guard let service = IOServiceMatching("DriverClient") else {
            return
        }
        
        let result = KextManagerLoadKextWithIdentifier(kextID, nil)
        if result != kIOReturnSuccess {
            Log(level: NuwaLogLevel.LOG_WARN, "Error occured in loading kext [\(String.init(format: "0x%x", result))].")
        }
        
        Log(level: NuwaLogLevel.LOG_INFO, "Wait for kext to be connected.")
        waitForDriver(matchingDict: service)
    }
    
    func unloadKernelExtension() {
        let result = KextManagerUnloadKextWithIdentifier(kextID)
        if result != kIOReturnSuccess {
            Log(level: NuwaLogLevel.LOG_WARN, "Error occured in unloading kext [\(String.init(format: "0x%x", result))].")
        }
        isConnected = 0
    }
}
