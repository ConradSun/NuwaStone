//
//  XPCConnection.swift
//  NuwaDaemon
//
//  Created by ConradSun on 2022/7/28.
//

import Foundation

@objc protocol ClientXPCProtocol {
}

@objc protocol DaemonXPCProtocol {
    func connectResponse(_ handler: @escaping (Bool) -> Void)
    func getProcPath(pid: Int32, eventHandler: @escaping (String, Int32) -> Void)
    func getProcCurrentDir(pid: Int32, eventHandler: @escaping (String, Int32) -> Void)
    func getProcArgs(pid: Int32, eventHandler: @escaping (Array<String>, Int32) -> Void)
}

class XPCConnection: NSObject {
    static let sharedInstance = XPCConnection()
    var listener: NSXPCListener?
    var connection: NSXPCConnection?
    var delegate: ClientXPCProtocol?
    
    private func getMachServiceName(from bundle: Bundle) -> String {
        let clientKeys = bundle.object(forInfoDictionaryKey: ClientName) as? [String: Any]
        let machServiceName = clientKeys?["MachServiceName"] as? String
        return machServiceName ?? ""
    }
    
    func startListener() {
        let newListener = NSXPCListener(machServiceName: DaemonName)
        newListener.delegate = self
        newListener.resume()
        listener = newListener
        Logger(.Info, "Start XPC listener successfully.")
    }
    
    func connectToDaemon(bundle: Bundle, delegate: ClientXPCProtocol, handler: @escaping (Bool) -> Void) {
        self.delegate = delegate
        guard connection == nil else {
            Logger(.Info, "Client already connected.")
            handler(true)
            return
        }
        guard getMachServiceName(from: bundle) == ClientName else {
            handler(false)
            return
        }
        
        let newConnection = NSXPCConnection(machServiceName: DaemonName)
        newConnection.exportedObject = delegate
        newConnection.exportedInterface = NSXPCInterface(with: ClientXPCProtocol.self)
        newConnection.remoteObjectInterface = NSXPCInterface(with: DaemonXPCProtocol.self)
        connection = newConnection
        newConnection.resume()
        
        let proxy = newConnection.remoteObjectProxyWithErrorHandler { error in
            Logger(.Error, "Failed to connect with error [\(error)]")
            self.connection?.invalidate()
            self.connection = nil
            handler(false)
        } as? DaemonXPCProtocol
        
        proxy?.connectResponse(handler)
    }
}

extension XPCConnection: NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        Logger(.Info, "shouldAcceptNewConnection")
        newConnection.exportedObject = self
        newConnection.exportedInterface = NSXPCInterface(with: DaemonXPCProtocol.self)
        newConnection.remoteObjectInterface = NSXPCInterface(with: ClientXPCProtocol.self)
        newConnection.invalidationHandler = {
            self.connection = nil
            Logger(.Info, "Client disconnected.")
        }
        newConnection.interruptionHandler = {
            self.connection = nil
            Logger(.Info, "Client interrupted.")
        }
        
        connection = newConnection
        newConnection.resume()
        return true
    }
}

extension XPCConnection: DaemonXPCProtocol {
    private func getSysctlArgmax() -> Int {
        var argmax: Int = 0
        var mib: [Int32] = [CTL_KERN, KERN_ARGMAX]
        var size = Swift.Int(MemoryLayout.size(ofValue: argmax))
        
        guard sysctl(&mib, 2, &argmax, &size, nil, 0) == 0 else {
            return 0
        }
        return argmax
    }
    
    private func getProcArgs(pid: Int32, args: UnsafeMutablePointer<CChar>, size: UnsafeMutablePointer<Int>) -> Bool {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        guard sysctl(&mib, 3, args, size, nil, 0) >= 0 else {
            return false
        }
        return true
    }
    
    func connectResponse(_ handler: @escaping (Bool) -> Void) {
        Logger(.Info, "Nuwa client connected.")
        handler(true)
    }
    
    func getProcPath(pid: Int32, eventHandler: @escaping (String, Int32) -> Void) {
        var buffer = [CChar](repeating: 0, count: Swift.Int(PROC_PIDPATHINFO_SIZE))
        guard proc_pidpath(Int32(pid), &buffer, UInt32(buffer.count)) > 0 else {
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
        guard proc_pidinfo(Int32(pid), PROC_PIDVNODEPATHINFO, 0, &info, Int32(MemoryLayout.size(ofValue: info))) > 0 else {
            if errno != ESRCH {
                Logger(.Debug, "Failed to get proc [\(pid)] cwd for errno [\(errno)]")
            }
            eventHandler("", errno)
            return
        }
        eventHandler(String(cString: &info.pvi_cdir.vip_path.0), 0)
    }
    
    func getProcArgs(pid: Int32, eventHandler: @escaping (Array<String>, Int32) -> Void) {
        var argc: Int32 = 0
        var argv = Array<String>()
        var argmax = getSysctlArgmax()
        let size = MemoryLayout.size(ofValue: argc)
        var begin = size
        
        if argmax == 0 {
            eventHandler(argv, EPERM)
            return
        }
        var args = [CChar](repeating: CChar.zero, count: Int(argmax))
        guard getProcArgs(pid: Int32(pid), args: &args, size: &argmax) else {
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
        
        if argv.count >= 1 {
            argv.remove(at: 0)
        }
        eventHandler(argv, 0)
    }
}
