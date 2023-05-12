//
//  DeviceInfo.swift
//  NuwaClient
//
//  Created by ConradSun on 2023/5/11.
//

import IOKit.ps
import Foundation

func getDeviceName() -> String {
    return ProcessInfo.processInfo.hostName
}

func getSystemVersion() -> String {
    return ProcessInfo.processInfo.operatingSystemVersionString
}

func getProcessorArch() -> String {
    var size = 0
    sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
    var chip = [CChar](repeating: 0, count: Int(size))
    sysctlbyname("machdep.cpu.brand_string", &chip, &size, nil, 0)

    let chipString = String(cString: chip)
    return chipString
}

func getPhysicalMemory() -> String {
    let memory = ProcessInfo.processInfo.physicalMemory
    let memFloat = Double(memory) / 1000000000.0
    let memoryInfo = String(format: "%.2f G", memFloat)
    return memoryInfo
}

func getSIPStatus() -> String {
    let task = Process()
    let pipe = Pipe()
    task.arguments = ["status"]
    task.standardOutput = pipe
    
    if #available(macOS 10.13, *) {
        task.executableURL = URL(fileURLWithPath: "/usr/bin/csrutil")
        try? task.run()
    } else {
        task.launchPath = "/usr/bin/csrutil"
        task.launch()
    }
    
    var output = Data()
    if #available(macOS 10.15.4, *) {
        output = try! pipe.fileHandleForReading.readToEnd()!
    } else {
        output = pipe.fileHandleForReading.readDataToEndOfFile()
    }
    
    let result = String(data: output, encoding: .utf8)
    if result == "System Integrity Protection status: enabled.\n" {
        return "Enabled"
    }
    else if result == "System Integrity Protection status: disabled.\n" {
        return "Disabled"
    }
    else {
        return "Unknown"
    }
}

func getTotalRAM() -> String {
    let fileManager = FileManager.default
    let systemAttr = try? fileManager.attributesOfFileSystem(forPath: "/")
    guard let totalSize = systemAttr?[.systemSize] as? Int else {
        return ""
    }
    
    let totalSpace = Double(totalSize) / 1000000000.0
    let totalMem = String(format: "%.2f G", totalSpace)
    return totalMem
}

func getAvailableRAM() -> String {
    let fileManager = FileManager.default
    let systemAttr = try? fileManager.attributesOfFileSystem(forPath: "/")
    guard let freeSize = systemAttr?[.systemFreeSize] as? Int else {
        return ""
    }
    
    let freeSpace = Double(freeSize) / 1000000000.0
    let avaliableMem = String(format: "%.2f G", freeSpace)
    return avaliableMem
}

func getBatteryState() -> String {
    let powerInfo = IOPSCopyPowerSourcesInfo().takeRetainedValue()
    let powerSources = IOPSCopyPowerSourcesList(powerInfo).takeRetainedValue() as Array
    
    guard let powerSource = powerSources.first else {
        return "Unknown"
    }
    
    let batteryDesc = IOPSGetPowerSourceDescription(powerInfo, powerSource).takeUnretainedValue() as Dictionary
    
    let batteryKey = kIOPSBatteryHealthKey as NSString
    guard let batteryState = batteryDesc[batteryKey] as? String else {
        return "Unknown"
    }
    return batteryState
}

func getDeviceLanguage() -> String {
    if #available(macOS 13, *) {
        return Locale.current.language.languageCode?.identifier ?? "Unknown"
    } else {
        return Locale.current.languageCode ?? "Unknown"
    }
}
