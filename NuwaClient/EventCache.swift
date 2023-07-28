//
//  NuwaCache.swift
//  NuwaStone
//
//  Created by ConradSun on 2022/7/24.
//

import Foundation

struct ProcessCacheInfo {
    var user: String
    var ppid: Int32
    var path: String
    var args: [String]
    var cwd: String
    var bundleID: String?
    var codeSign: String?
    
    init() {
        user = ""
        ppid = 0
        path = ""
        args = [String]()
        cwd = ""
        bundleID = nil
        codeSign = nil
    }
}

class ProcessCache {
    static let shared = ProcessCache()
    private var cacheDict = [Int32: ProcessCacheInfo]()
    let cacheQueue = DispatchQueue(label: "com.nuwastone.eventcache.queue", attributes: .concurrent)
    
    private func getActivePids() -> (UnsafeMutablePointer<Int32>, Int32) {
        var count = proc_listallpids(nil, 0)
        let pidArray = UnsafeMutablePointer<Int32>.allocate(capacity: Int(count)*2)
        
        count = proc_listallpids(pidArray, Int32(MemoryLayout<Int32>.size)*count*2)
        return (pidArray, count)
    }
    
    private func fillCacheInfo(_ pointer: UnsafeMutablePointer<NuwaEventInfo>) {
        pointer.pointee.fillProcPpid {_ in }
        pointer.pointee.fillProcPath {_ in }
        pointer.pointee.fillProcCurrentDir {_ in }
        pointer.pointee.fillProcArgs {_ in }
        pointer.pointee.fillBundleIdentifier()
        pointer.pointee.fillCodeSign()
    }
    
    init() {
        Timer.scheduledTimer(timeInterval: 1800, target: self, selector: #selector(cleanExitedProcs), userInfo: nil, repeats: true)
    }
    
    @objc func cleanExitedProcs() {
        let (pidArray, count) = getActivePids()
        defer {
            pidArray.deallocate()
        }
        
        let pids = cacheQueue.sync {
            cacheDict.keys
        }
        for pid in pids {
            var isAlived = false
            for i in 0 ..< count {
                if pid == pidArray[Int(i)] {
                    isAlived = true
                    break
                }
            }
            if !isAlived {
                cacheQueue.async(flags: .barrier) {
                    self.cacheDict[pid] = nil
                }
            }
        }
    }
    
    func initProcCache() {
        let (pidArray, count) = getActivePids()
        defer {
            pidArray.deallocate()
        }
        
        for i in 0 ..< count {
            var event = NuwaEventInfo()
            event.pid = pidArray[Int(i)]
            fillCacheInfo(&event)
            updateCache(event)
        }
    }
    
    func updateCache(_ event: NuwaEventInfo) {
        var info = ProcessCacheInfo()
        info.user = event.user
        info.ppid = event.ppid
        info.path = event.procPath
        info.args = event.procArgs
        info.cwd = event.procCWD
        info.bundleID = event.props[PropBundleID]
        info.codeSign = event.props[PropCodeSign]
        
        cacheQueue.async(flags: .barrier) {
            self.cacheDict[event.pid] = info
        }
        Logger(.Debug, "Add process [\(event.pid): \(event.procPath)] to cache.")
    }
    
    func getFromCache(_ event: inout NuwaEventInfo) {
        let info = cacheQueue.sync {
            cacheDict[event.pid]
        }
        
        if info == nil {
            Logger(.Debug, "Failed to find proc [\(event.pid)] info in cache.")
            // fillCacheInfo(&event)
            // updateCache(event)
            return
        }
        
        if event.user.isEmpty {
            event.user = info!.user
        }
        event.ppid = info!.ppid
        event.procPath = info!.path
        event.procCWD = info!.cwd
        event.procArgs = info!.args
        event.props[PropBundleID] = info!.bundleID
        event.props[PropCodeSign] = info!.codeSign
    }
}
