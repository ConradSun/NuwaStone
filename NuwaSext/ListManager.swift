//
//  ListManager.swift
//  NuwaSext
//
//  Created by ConradSun on 2022/8/22.
//

import Foundation

/// List manager for event filtering
class ListManager {
    static let shared = ListManager()
    private var allowExecList = Set<UInt64>()
    private var denyExecList = Set<UInt64>()
    private var filePathsForFileMute = Set<UInt64>()
    private var procPathsForFileMute = Set<UInt64>()
    // Lists are written from the XPC queue and read from the ES event queue,
    // so guard them with a concurrent queue: reads run in parallel, updates are barriers.
    private let listQueue = DispatchQueue(label: "com.nuwastone.sext.listqueue", attributes: .concurrent)

    func updateAuthProcList(vnodeID: [UInt64], type: NuwaMuteType) {
        listQueue.async(flags: .barrier) {
            if type == .AllowProcExec {
                self.allowExecList.removeAll()
                for vnode in vnodeID {
                    self.allowExecList.update(with: vnode)
                }
            } else {
                self.denyExecList.removeAll()
                for vnode in vnodeID {
                    self.denyExecList.update(with: vnode)
                }
            }
        }
    }

    func updateFilterFileList(vnodeID: [UInt64], type: NuwaMuteType) {
        listQueue.async(flags: .barrier) {
            if type == .FilterFileByFilePath {
                self.filePathsForFileMute.removeAll()
                for vnode in vnodeID {
                    self.filePathsForFileMute.update(with: vnode)
                }
            } else {
                self.procPathsForFileMute.removeAll()
                for vnode in vnodeID {
                    self.procPathsForFileMute.update(with: vnode)
                }
            }
        }
    }

    func shouldAllowProcExec(vnodeID: UInt64) -> Bool? {
        return listQueue.sync {
            if allowExecList.contains(vnodeID) {
                return true
            } else if denyExecList.contains(vnodeID) {
                return false
            } else {
                return nil
            }
        }
    }

    func shouldAbandonFileEvent(fileVnodeID: UInt64, procVnodeID: UInt64) -> Bool {
        return listQueue.sync {
            filePathsForFileMute.contains(fileVnodeID) || procPathsForFileMute.contains(procVnodeID)
        }
    }
}
