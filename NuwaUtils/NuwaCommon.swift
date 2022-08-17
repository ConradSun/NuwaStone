//
//  NuwaConst.swift
//  NuwaStone
//
//  Created by ConradSun on 2022/7/28.
//

import Foundation

let DaemonName = "NuwaDaemon"
let ClientName = "NuwaClient"
let DaemonBundle = "com.nuwastone.service"
let ClientBundle = "com.nuwastone.client"

let SextBundle = "com.nuwastone.service.eps"
let KextBundle = "com.nuwastone.service.eps"
let KextService = "DriverService"

let MachServiceKey = "MachServiceName"

let MaxIPLength = 41

enum ESClientError: Error {
    case success
    case missingEntitlements
    case alreadyEnabled
    case newClientError
    case failedSubscription
}

fileprivate func getSysctlArgmax() -> Int {
    var argmax: Int = 0
    var mib: [Int32] = [CTL_KERN, KERN_ARGMAX]
    var size = MemoryLayout<Int>.size
    
    guard sysctl(&mib, 2, &argmax, &size, nil, 0) == 0 else {
        return 0
    }
    return argmax
}

fileprivate func getProcArgs(pid: Int32, args: UnsafeMutablePointer<CChar>, size: UnsafeMutablePointer<Int>) -> Bool {
    var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
    guard sysctl(&mib, 3, args, size, nil, 0) >= 0 else {
        return false
    }
    return true
}

func getProcPath(pid: Int32, eventHandler: @escaping (String, Int32) -> Void) {
    var buffer = [CChar](repeating: 0, count: Int(PROC_PIDPATHINFO_SIZE))
    guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else {
        if errno != ESRCH {
            Logger(.Debug, "Failed to get proc [\(pid)] path for errno [\(errno)]")
        }
        eventHandler("", errno)
        return
    }
    eventHandler(String(cString: buffer), 0)
}

func getProcCurrentDir(pid: Int32, eventHandler: @escaping (String, Int32) -> Void) {
    var info = proc_vnodepathinfo()
    guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, Int32(MemoryLayout<proc_vnodepathinfo>.size)) > 0 else {
        if errno != ESRCH {
            Logger(.Debug, "Failed to get proc [\(pid)] cwd for errno [\(errno)]")
        }
        eventHandler("", errno)
        return
    }
    eventHandler(String(cString: &info.pvi_cdir.vip_path.0), 0)
}

func getProcArgs(pid: Int32, eventHandler: @escaping ([String], Int32) -> Void) {
    var argc: Int32 = 0
    var argv = [String]()
    var argmax = getSysctlArgmax()
    let size = MemoryLayout<Int32>.size
    var begin = size
    
    if argmax == 0 {
        eventHandler(argv, EPERM)
        return
    }
    var args = [CChar](repeating: CChar.zero, count: Int(argmax))
    guard getProcArgs(pid: pid, args: &args, size: &argmax) else {
        eventHandler(argv, EPERM)
        return
    }
    NSData(bytes: args, length: size).getBytes(&argc, length: size)
    
    repeat {
        if args[begin] == 0x0 {
            begin += 1
            break
        }
        begin += 1
    } while begin < argmax
    if begin == argmax {
        eventHandler(argv, EPERM)
        return
    }
    
    var last = begin
    while begin < argmax && argc > 0 {
        if args[begin] == 0x0 {
            var temp = Array(args[last...begin])
            let arg = String(cString: &temp)
            if arg.count > 0 {
                argv.append(arg)
            }
            
            last = begin + 1
            argc -= 1
        }
        begin += 1
    }
    
    eventHandler(argv, 0)
}

func getNameFromUid(_ uid: uid_t) -> String {
    guard let name = getpwuid(uid)?.pointee.pw_name else {
        return ""
    }
    return String(cString: name)
}
