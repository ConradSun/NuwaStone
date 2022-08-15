//
//  KextControl.swift
//  NuwaDaemon
//
//  Created by ConradSun on 2022/8/1.
//

import Foundation
import IOKit.kext

class KextControl {
    func loadExtension() -> Bool {
        let kextUrl = URL(fileURLWithPath: "Contents/PlugIns/NuwaStone.kext", relativeTo: Bundle.main.bundleURL)
        let result = KextManagerLoadKextWithURL(kextUrl as CFURL, nil)
        if result != kIOReturnSuccess {
            Logger(.Warning, "Error occured in loading kext [\(String.init(format: "0x%x", result))].")
            return false
        }

        return true
    }
    
    func unloadExtension() -> Bool {
        let kextID = CFStringCreateWithCStringNoCopy(kCFAllocatorDefault, KextBundle.cString(using: .utf8), kCFStringEncodingASCII, kCFAllocatorNull)
        let result = KextManagerUnloadKextWithIdentifier(kextID)
        if result != kIOReturnSuccess {
            Logger(.Warning, "Error occured in unloading kext [\(String.init(format: "0x%x", result))].")
            return false
        }

        return true
    }
}
