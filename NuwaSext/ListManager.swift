//
//  ListManager.swift
//  NuwaSext
//
//  Created by ConradSun on 2022/8/22.
//

import Foundation

class ListManager {
    static let shared = ListManager()
    private var allowExecList = Set<UInt64>()
    private var denyExecList = Set<UInt64>()
    private var filePathsForFileMute = Set<UInt64>()
    private var procPathsForFileMute = Set<UInt64>()
    
    func updateAuthProcList(vnodeID: [UInt64], type: NuwaMuteType) {
        if type == .AllowProcExec {
            allowExecList.removeAll()
            for vnode in vnodeID {
                allowExecList.update(with: vnode)
            }
        }
        else {
            denyExecList.removeAll()
            for vnode in vnodeID {
                denyExecList.update(with: vnode)
            }
        }
    }
    
    func updateFilterFileList(vnodeID: [UInt64], type: NuwaMuteType) {
        if type == .FilterFileByFilePath {
            filePathsForFileMute.removeAll()
            for vnode in vnodeID {
                filePathsForFileMute.update(with: vnode)
            }
        }
        else {
            procPathsForFileMute.removeAll()
            for vnode in vnodeID {
                procPathsForFileMute.update(with: vnode)
            }
        }
    }
    
    func shouldAllowProcExec(vnodeID: UInt64) -> Bool? {
        if allowExecList.contains(vnodeID) {
            return true
        }
        else if denyExecList.contains(vnodeID) {
            return false
        }
        else {
            return nil
        }
    }
    
    func shouldAbandonFileEvent(fileVnodeID: UInt64, procVnodeID: UInt64) -> Bool {
        if filePathsForFileMute.contains(fileVnodeID) || procPathsForFileMute.contains(procVnodeID) {
            return true
        }
        
        return false
    }
}
