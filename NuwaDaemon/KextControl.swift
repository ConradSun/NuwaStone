//
//  KextControl.swift
//  NuwaDaemon
//
//  Created by ConradSun on 2022/8/1.
//

import Foundation
import IOKit.kext

class KextControl {
    static func loadExtension() -> Bool {
        let kextUrl = CFURLCreateWithBytes(kCFAllocatorDefault, kDriverPath, strlen(kDriverPath), kCFStringEncodingASCII, nil)
        let result = KextManagerLoadKextWithURL(kextUrl, nil)
        if result != kIOReturnSuccess {
            Logger(.Warning, "Error occured in loading kext [\(String.init(format: "0x%x", result))].")
            return false
        }

        return true
    }
    
    static func unloadExtension() -> Bool {
        let kextID = CFStringCreateWithCStringNoCopy(kCFAllocatorDefault, kDriverIdentifier, kCFStringEncodingASCII, kCFAllocatorNull)
        let result = KextManagerUnloadKextWithIdentifier(kextID)
        if result != kIOReturnSuccess {
            Logger(.Warning, "Error occured in unloading kext [\(String.init(format: "0x%x", result))].")
            return false
        }

        return true
    }
}
