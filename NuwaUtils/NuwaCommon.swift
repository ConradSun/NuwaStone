//
//  NuwaConst.swift
//  NuwaStone
//
//  Created by ConradSun on 2022/7/28.
//

import Foundation

let DaemonName      = "NuwaDaemon"
let ClientName      = "NuwaClient"
let DaemonBundle    = "com.nuwastone.service"
let ClientBundle    = "com.nuwastone.client"

let SextBundle      = "com.nuwastone.service.eps"
let KextBundle      = "com.nuwastone.service.eps"
let KextService     = "DriverService"

let MainWindowName  = "NuwaStoneMainWindow"

let MachServiceKey  = "MachServiceName"

let DurationChanged = "Clear Duration Changed"

let VersionInfoKey  = "CFBundleShortVersionString"
let ReleaseURL      = "https://github.com/ConradSun/NuwaStone/releases/latest"
let PackageURL      = "https://github.com/ConradSun/NuwaStone/releases/latest/download/NuwaStone.pkg"

let UserLogLevel        = "Log Level"
let UserAuditSwitch     = "Audit Switch"
let UserClearDuration   = "Clear Duration"
let UserAllowExecList   = "Allow Exec List"
let UserDenyExecList    = "Deny Exec List"
let UserMuteFileByFile  = "File Paths for Filtering File"
let UserMuteFileByProc  = "Proc Paths for Filtering File"
let UserMuteNetByProc   = "Proc Paths for Filtering Net"
let UserMuteNetByIP     = "IP Addrs for Filtering Net"

let PropBundleID    = "Bundle ID"
let PropCodeSign    = "Code Sign"
let PropExitCode    = "Exit Code"
let PropFilePath    = "File Path"
let PropSrcPath     = "From"
let PropDstPath     = "Move to"
let PropProtocol    = "Protocol"
let PropLocalAddr   = "Local"
let PropRemoteAddr  = "Remote"
let PropQueryStatus = "Status"
let PropDomainName  = "Query"
let PropReplyResult = "Reply"
let MaxIPLength     = 41
let MaxWaitTime     = 20000 //   ms

/// Error for ESClient init
enum ESClientError: Error {
    case Success
    case MissingEntitlements
    case AlreadyEnabled
    case NewClientError
    case FailedSubscription
}

/// Called to get argmax by sysctl, used for func getProcArgs
/// - Returns: Max number of arguments
fileprivate func getSysctlArgmax() -> Int {
    var argmax: Int = 0
    var mib: [Int32] = [CTL_KERN, KERN_ARGMAX]
    var size = MemoryLayout<Int>.size
    
    guard sysctl(&mib, 2, &argmax, &size, nil, 0) == 0 else {
        return 0
    }
    return argmax
}

/// Called to get process arguments, used for func getProcArgs
/// - Parameters:
///   - pid: Process ID
///   - args: CChar array to store arguments
///   - size: Max number of arguments
/// - Returns: Whether succeed or not
fileprivate func getProcArgs(pid: Int32, args: UnsafeMutablePointer<CChar>, size: UnsafeMutablePointer<Int>) -> Bool {
    var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
    guard sysctl(&mib, 3, args, size, nil, 0) >= 0 else {
        return false
    }
    return true
}

/// Called to get process parent pid
/// - Parameters:
///   - pid: Process ID
///   - eventHandler: Code block to process result and error
func getProcPpid(pid: Int32, eventHandler: @escaping (Int32, Int32) -> Void) {
    var info = proc_bsdinfo()
    let infoSize = MemoryLayout<proc_bsdinfo>.size
    guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(infoSize)) > 0 else {
        if errno != ESRCH {
            Logger(.Debug, "Failed to get proc [\(pid)] ppid for errno [\(errno)]")
        }
        eventHandler(0, errno)
        return
    }
    eventHandler(Int32(info.pbi_ppid), 0)
}

/// Called to get process path
/// - Parameters:
///   - pid: Process ID
///   - eventHandler: Code block to process result and error
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

/// Called to get process current working directory
/// - Parameters:
///   - pid: Process ID
///   - eventHandler: Code block to process result and error
func getProcCurrentDir(pid: Int32, eventHandler: @escaping (String, Int32) -> Void) {
    var info = proc_vnodepathinfo()
    let infoSize = MemoryLayout<proc_vnodepathinfo>.size
    guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, Int32(infoSize)) > 0 else {
        if errno != ESRCH {
            Logger(.Debug, "Failed to get proc [\(pid)] cwd for errno [\(errno)]")
        }
        eventHandler("", errno)
        return
    }
    
    let data = Data(bytes: &info.pvi_cdir.vip_path.0, count: MemoryLayout.size(ofValue: info.pvi_cdir.vip_path)/2)
    eventHandler(String(data: data, encoding: .utf8)!, 0)
}

/// Called to get process arguments
/// - Parameters:
///   - pid: Process ID
///   - eventHandler: Code block to process result and error
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
    
    repeat {
        if args[begin] != 0x0 {
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


/// Called to get user name by uid
/// - Parameter uid: user ID
/// - Returns: User name
func getNameFromUid(_ uid: uid_t) -> String {
    guard let name = getpwuid(uid)?.pointee.pw_name else {
        return ""
    }
    return String(cString: name)
}

/// Called to get process codesign by process path
/// - Parameter path: Process path
/// - Returns: Code signature
func getSignInfoFromPath(_ path: String) -> [String] {
    let fileUrl = URL(fileURLWithPath: path)
    var secCode: SecStaticCode?
    var status = SecStaticCodeCreateWithPath(fileUrl as CFURL, SecCSFlags(rawValue: 0), &secCode)
    if status != errSecSuccess || secCode == nil {
        Logger(.Warning, "Failed to create static signed code for [\(path)] with error [\(status)].")
        return []
    }
    
    var secDict: CFDictionary?
    status = SecCodeCopySigningInformation(secCode!, SecCSFlags(rawValue: kSecCSSigningInformation), &secDict)
    if status != errSecSuccess || secDict == nil {
        Logger(.Warning, "Failed to copy signed info for [\(path)] with error [\(status)].")
        return []
    }
    let signedDict = secDict! as NSDictionary
    guard let certChain = signedDict[kSecCodeInfoCertificates as NSString] as? NSArray else {
        return []
    }
    
    var signInfo = [String]()
    for cert in certChain {
        var name: CFString?
        status = SecCertificateCopyCommonName(cert as! SecCertificate, &name)
        if status != errSecSuccess || name == nil {
            continue
        }
        signInfo.append((name! as String))
    }
    
    return signInfo
}

/// Called to get file vnode ID (dev|ino) by file path
/// - Parameter path: File path
/// - Returns: Vnode ID
func getFileVnodeID(_ path: String) -> UInt64 {
    var fileStat = stat()
    stat(path.cString(using: .utf8), &fileStat)
    let dev = UInt64(truncating: fileStat.st_dev as NSNumber)
    let ino = UInt64(truncating: fileStat.st_ino as NSNumber)
    let vnodeID = (dev << 32) | ino
    return vnodeID
}

/// Called to execute custom process
/// - Parameters:
///   - path: Process path
///   - args: Arguments for execution
/// - Returns: Process running results, nil means execution failure
func launchTask(path: String, args: [String]) -> String? {
    let task = Process()
    let pipe = Pipe()
    task.arguments = args
    task.standardOutput = pipe
    
    if #available(macOS 10.13, *) {
        task.executableURL = URL(fileURLWithPath: path)
        try? task.run()
    } else {
        task.launchPath = path
        task.launch()
    }
    
    var output = Data()
    if #available(macOS 10.15.4, *) {
        guard let value = try? pipe.fileHandleForReading.readToEnd() else {
            return nil
        }
        output = value
    } else {
        output = pipe.fileHandleForReading.readDataToEndOfFile()
    }
    
    guard let result = String(data: output, encoding: .utf8) else {
        return nil
    }
    return result
}
