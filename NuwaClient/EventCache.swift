//
//  NuwaCache.swift
//  NuwaStone
//
//  Created by ConradSun on 2022/7/24.
//
//  This file provides process information caching for NuwaStone.
//  It defines a cache structure and logic to efficiently retrieve and update process-related metadata.
//

import Foundation

/// Structure holding cached process information for quick lookup.
struct ProcessCacheInfo {
    var user: String           // Username of the process owner
    var ppid: Int32            // Parent process ID
    var path: String           // Executable path
    var args: [String]         // Process arguments
    var cwd: String            // Current working directory
    var bundleID: String?      // App bundle identifier (if available)
    var codeSign: String?      // Code signature info (if available)
    
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

/// Singleton class for process information caching.
/// Used to fill and retrieve process metadata for events efficiently.
class ProcessCache {
    static let shared = ProcessCache()
    private var cacheDict = [Int32: ProcessCacheInfo]() // PID to info mapping
    let cacheQueue = DispatchQueue(label: "com.nuwastone.eventcache.queue", attributes: .concurrent)
    
    /// Returns a pointer to the list of active PIDs and the count.
    private func getActivePids() -> (UnsafeMutablePointer<Int32>, Int32) {
        var count = proc_listallpids(nil, 0)
        let pidArray = UnsafeMutablePointer<Int32>.allocate(capacity: Int(count)*2)
        
        count = proc_listallpids(pidArray, Int32(MemoryLayout<Int32>.size)*count*2)
        return (pidArray, count)
    }
    
    /// Fills process-related fields in a NuwaEventInfo pointer.
    private func fillCacheInfo(_ pointer: UnsafeMutablePointer<NuwaEventInfo>) {
        pointer.pointee.fillProcPpid {_ in }
        pointer.pointee.fillProcPath {_ in }
        pointer.pointee.fillProcCurrentDir {_ in }
        pointer.pointee.fillProcArgs {_ in }
        pointer.pointee.fillBundleIdentifier()
        pointer.pointee.fillCodeSign()
    }
    
    /// Initializes the process cache and schedules periodic cleanup.
    init() {
        Timer.scheduledTimer(timeInterval: 1800, target: self, selector: #selector(cleanExitedProcs), userInfo: nil, repeats: true)
    }
    
    /// Removes exited processes from the cache.
    @objc func cleanExitedProcs() {
        let (pidArray, count) = getActivePids()
        defer {
            pidArray.deallocate()
        }

        // Convert the C-style array of active PIDs to a Swift Set for O(1) lookups.
        let activePids = Set(UnsafeBufferPointer(start: pidArray, count: Int(count)))
        
        cacheQueue.async(flags: .barrier) {
            for pid in self.cacheDict.keys {
                if !activePids.contains(pid) {
                    self.cacheDict[pid] = nil
                    Logger(.Debug, "Remove process [\(pid)] from cache.")
                }
            }
        }
    }
    
    /// Initializes the process cache with currently running processes.
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
    
    /// Updates the cache with the given event's process information.
    /// - Parameter event: The event containing process info to cache.
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
    
    /// Fills the given event with cached process information if available.
    /// - Parameter event: The event to fill (inout).
    func getFromCache(_ event: inout NuwaEventInfo) {
        let info = cacheQueue.sync {
            cacheDict[event.pid]
        }
        
        if info == nil {
            // Cache are not updated here, as ProcessCreate events may be reported later than other types
            // This is followed by the required ProcessCreate events to update the cache
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
