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
    
    init() {
        Timer.scheduledTimer(timeInterval: 1800, target: self, selector: #selector(runloopTask), userInfo: nil, repeats: true)
    }
    
    @objc func runloopTask() {
        var count = proc_listallpids(nil, 0)
        count *= 2
        var pids = Array<Int32>(repeating: 0, count: Int(count))
        count = proc_listallpids(&pids, Int32(MemoryLayout.size(ofValue: pids)))

        for pid in self.cacheDict.keys {
            if !pids.contains(Int32(pid)) {
                self.cacheDict.removeValue(forKey: pid)
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
            event.fillProcPath()
            event.fillProcCurrentDir()
            event.fillProcArgs()
            updateCache(event)
        }
        else {
            event.procPath = info!.path
            event.props.updateValue(info!.cwd, forKey: ProcessCWD)
            event.props.updateValue(info!.args, forKey: ProcessArgs)
        }
    }
}
