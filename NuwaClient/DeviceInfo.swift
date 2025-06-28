//
//  DeviceInfo.swift
//  NuwaClient
//
//  Created by ConradSun on 2023/5/11.
//

import IOKit.ps
import Foundation

private enum DeviceInfoConst {
    static let unknown = "Unknown"
    static let enabled = "Enabled"
    static let disabled = "Disabled"
}

func getDeviceName() -> String {
    return ProcessInfo.processInfo.hostName
}

func getSystemVersion() -> String {
    return ProcessInfo.processInfo.operatingSystemVersionString
}

func getProcessorArch() -> String {
    var size = 0
    sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
    guard size > 0 else { return DeviceInfoConst.unknown }
    var chip = [CChar](repeating: 0, count: Int(size))
    sysctlbyname("machdep.cpu.brand_string", &chip, &size, nil, 0)
    let chipString = String(cString: chip)
    return chipString
}

func getPhysicalMemory() -> String {
    let memory = ProcessInfo.processInfo.physicalMemory
    let memFloat = Double(memory) / (1024*1024*1024.0)
    let memoryInfo = String(format: "%.2f G", memFloat)
    return memoryInfo
}

func getSIPStatus() -> String {
    guard let result = launchTask(path: "/usr/bin/csrutil", args: ["status"]) else {
        return DeviceInfoConst.unknown
    }
    if result.contains("enabled") {
        return DeviceInfoConst.enabled
    } else if result.contains("disabled") {
        return DeviceInfoConst.disabled
    } else {
        return DeviceInfoConst.unknown
    }
}

func getTotalRAM() -> String {
    let fileManager = FileManager.default
    let systemAttr = try? fileManager.attributesOfFileSystem(forPath: "/")
    guard let totalSize = systemAttr?[.systemSize] as? UInt64 else {
        return DeviceInfoConst.unknown
    }
    let totalSpace = Double(totalSize) / (1024*1024*1024.0)
    let totalMem = String(format: "%.2f G", totalSpace)
    return totalMem
}

func getAvailableRAM() -> String {
    let fileManager = FileManager.default
    let systemAttr = try? fileManager.attributesOfFileSystem(forPath: "/")
    guard let freeSize = systemAttr?[.systemFreeSize] as? UInt64 else {
        return DeviceInfoConst.unknown
    }
    let freeSpace = Double(freeSize) / (1024*1024*1024.0)
    let avaliableMem = String(format: "%.2f G", freeSpace)
    return avaliableMem
}

func getBatteryState() -> String {
    let powerInfo = IOPSCopyPowerSourcesInfo().takeRetainedValue()
    let powerSources = IOPSCopyPowerSourcesList(powerInfo).takeRetainedValue() as Array
    let powerSource = powerSources.first
    guard let batteryDesc = IOPSGetPowerSourceDescription(powerInfo, powerSource)?.takeUnretainedValue() as? [String: Any] else {
        return DeviceInfoConst.unknown
    }
    let batteryKey = kIOPSBatteryHealthKey as String
    guard let batteryState = batteryDesc[batteryKey] as? String else {
        return DeviceInfoConst.unknown
    }
    return batteryState
}

func getDeviceLanguage() -> String {
    if #available(macOS 13, *) {
        return Locale.current.language.languageCode?.identifier
            ?? Locale.preferredLanguages.first
            ?? DeviceInfoConst.unknown
    } else {
        return Locale.current.languageCode
            ?? Locale.preferredLanguages.first
            ?? DeviceInfoConst.unknown
    }
}
