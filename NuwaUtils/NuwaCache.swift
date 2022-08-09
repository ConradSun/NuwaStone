//
//  NuwaCache.swift
//  NuwaStone
//
//  Created by ConradSun on 2022/7/24.
//

import Foundation

struct ProcessCacheInfo {
    var path: String
    var args: Array<String>
    var cwd: String
    
    init() {
        path = ""
        args = Array<String>()
        cwd = ""
    }
}

class ProcessCache {
    static let sharedInstance = ProcessCache()
    private let cacheQueue = DispatchQueue(label: "com.nuwastone.proccache.queue")
    private var cacheDict = Dictionary<UInt32, ProcessCacheInfo>()
    
    private func getActivePids() -> (UnsafeMutablePointer<Int32>, Int32) {
        var count = proc_listallpids(nil, 0)
        let pidArray = UnsafeMutablePointer<Int32>.allocate(capacity: Int(count)*2)
        
        count = proc_listallpids(pidArray, Int32(MemoryLayout<Int32>.size)*count*2)
        return (pidArray, count)
    }
    
    private func initProcCache() {
        let (pidArray, count) = getActivePids()
        defer {
            pidArray.deallocate()
        }
        
        for i in 0..<count {
            let event = NuwaEventInfo()
            event.pid = UInt32(pidArray[Int(i)])
            event.fillProcPath()
            event.fillProcCurrentDir()
            event.fillProcArgs()
            updateCache(event)
        }
    }
    
    init() {
        initProcCache()
        Timer.scheduledTimer(timeInterval: 1800, target: self, selector: #selector(runloopTask), userInfo: nil, repeats: true)
    }
    
    @objc func runloopTask() {
        let (pids, count) = getActivePids()
        defer {
            pids.deallocate()
        }

        var pidArray = Array<Int32>(repeating: 0, count: Int(count))
        pidArray.withUnsafeMutableBufferPointer({ ptr -> UnsafeMutablePointer<Int32> in
            return ptr.baseAddress!
        }).initialize(from: pids, count: Int(count))
        
        for pid in self.cacheDict.keys {
            if pidArray.contains(Int32(pid)){
                cacheQueue.sync {
                    self.cacheDict.removeValue(forKey: pid)
                    return
                }
            }
        }
    }
    
    func updateCache(_ event: NuwaEventInfo) {
        var info = ProcessCacheInfo()
        info.path = event.procPath
        if event.props[ProcessArgs] != nil {
            info.args = event.props[ProcessArgs] as! Array<String>
        }
        if event.props[ProcessCWD] != nil {
            info.cwd = event.props[ProcessCWD] as! String
        }
        
        cacheQueue.sync {
            cacheDict.updateValue(info, forKey: event.pid)
            return
        }
    }
    
    func getFromCache(_ event: inout NuwaEventInfo) {
        let info = cacheDict[event.pid]
        if info == nil {
            Logger(.Warning, "Failed to find proc [\(event.pid)] info in cache.")
            return
        }
        event.procPath = info!.path
        event.props.updateValue(info!.cwd, forKey: ProcessCWD)
        event.props.updateValue(info!.args, forKey: ProcessArgs)
    }
}
