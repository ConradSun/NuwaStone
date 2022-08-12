//
//  NuwaCache.swift
//  NuwaStone
//
//  Created by ConradSun on 2022/7/24.
//

import Foundation

struct ProcessCacheInfo {
    var path: String
    var args: [String]
    var cwd: String
    
    init() {
        path = ""
        args = [String]()
        cwd = ""
    }
}

class ProcessCache {
    static let sharedInstance = ProcessCache()
    private var cacheDict = [Int32: ProcessCacheInfo]()
    private lazy var proxy = XPCConnection.sharedInstance.connection?.remoteObjectProxy as? DaemonXPCProtocol
    
    private func getActivePids() -> (UnsafeMutablePointer<Int32>, Int32) {
        var count = proc_listallpids(nil, 0)
        let pidArray = UnsafeMutablePointer<Int32>.allocate(capacity: Int(count)*2)
        
        count = proc_listallpids(pidArray, Int32(MemoryLayout<Int32>.size)*count*2)
        return (pidArray, count)
    }
    
    init() {
        Timer.scheduledTimer(timeInterval: 1800, target: self, selector: #selector(runloopTask), userInfo: nil, repeats: true)
    }
    
    @objc func runloopTask() {
        let (pidArray, count) = getActivePids()
        defer {
            pidArray.deallocate()
        }
        
        for pid in cacheDict.keys {
            var isAlived = false
            for i in 0 ..< count {
                if pid == pidArray[Int(i)] {
                    isAlived = true
                    break
                }
            }
            if !isAlived {
                cacheDict.removeValue(forKey: pid)
            }
        }
    }
    
    func initProcCache() {
        let (pidArray, count) = getActivePids()
        defer {
            pidArray.deallocate()
        }
        
        for i in 0 ..< count {
            let event = NuwaEventInfo()
            event.pid = pidArray[Int(i)]
            event.fillProcPath { error in
                if error == EPERM {
                    self.proxy?.getProcessPath(pid: event.pid, eventHandler: { path, error in
                        event.procPath = path
                    })
                }
            }
            event.fillProcCurrentDir { error in
                if error == EPERM {
                    self.proxy?.getProcessCurrentDir(pid: event.pid, eventHandler: { cwd, error in
                        event.procCWD = cwd
                    })
                }
            }
            event.fillProcArgs { error in
                if error == EPERM {
                    self.proxy?.getProcessArgs(pid: event.pid, eventHandler: { args, error in
                        event.procArgs = args
                    })
                }
            }
            updateCache(event)
        }
    }
    
    func updateCache(_ event: NuwaEventInfo) {
        var info = ProcessCacheInfo()
        info.path = event.procPath
        info.args = event.procArgs
        info.cwd = event.procCWD
        
        cacheDict.updateValue(info, forKey: event.pid)
    }
    
    func getFromCache(_ event: inout NuwaEventInfo) {
        let info = cacheDict[event.pid]
        if info == nil {
            Logger(.Warning, "Failed to find proc [\(event.pid)] info in cache.")
            return
        }
        event.procPath = info!.path
        event.procCWD = info!.cwd
        event.procArgs = info!.args
    }
}
