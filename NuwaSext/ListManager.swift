//
//  ListManager.swift
//  NuwaSext
//
//  Created by ConradSun on 2022/8/22.
//

import Foundation

class ListManager {
    static let shared = ListManager()
    private var authExecDict = [UInt64: Bool]()
    private var filterFileList = Set<UInt64>()
    
    func updateAuthProcList(vnodeID: UInt64, isWhite: Bool) {
        authExecDict[vnodeID] = isWhite
    }
    
    func removeAuthProcPath(vnodeID: UInt64, isWhite: Bool) {
        authExecDict[vnodeID] = nil
    }
    
    func updateFilterFileList(vnodeID: UInt64) {
        if vnodeID != 0 {
            filterFileList.update(with: vnodeID)
        }
    }
    
    func removeFilterFilePath(vnodeID: UInt64) {
        filterFileList.remove(vnodeID)
    }
    
    func containsAuthProcPath(vnodeID: UInt64) -> Bool? {
        return authExecDict[vnodeID]
    }
    
    func containsFilterFilePath(vnodeID: UInt64) -> Bool {
        if vnodeID == 0 {
            return false
        }
        return filterFileList.contains(vnodeID)
    }
}
