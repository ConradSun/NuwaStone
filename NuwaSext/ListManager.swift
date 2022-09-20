//
//  ListManager.swift
//  NuwaSext
//
//  Created by ConradSun on 2022/8/22.
//

import Foundation

class ListManager {
    static let shared = ListManager()
    private var whiteProcList = Set<UInt64>()
    private var blackProcList = Set<UInt64>()
    private var filterFileList = Set<UInt64>()
    
    func updateAuthProcList(vnodeID: UInt64, isWhite: Bool) {
        if isWhite {
            whiteProcList.update(with: vnodeID)
        }
        else {
            blackProcList.update(with: vnodeID)
        }
    }
    
    func removeAuthProcPath(vnodeID: UInt64, isWhite: Bool) {
        if isWhite {
            whiteProcList.remove(vnodeID)
        }
        else {
            blackProcList.remove(vnodeID)
        }
    }
    
    func updateFilterFileList(vnodeID: UInt64) {
        if vnodeID != 0 {
            filterFileList.update(with: vnodeID)
        }
    }
    
    func removeFilterFilePath(vnodeID: UInt64) {
        filterFileList.remove(vnodeID)
    }
    
    func containsAuthProcPath(vnodeID: UInt64, isWhite: inout Bool) -> Bool {
        if whiteProcList.contains(vnodeID) {
            isWhite = true
            return true
        }
        if blackProcList.contains(vnodeID) {
            isWhite = false
            return true
        }
        return false
    }
    
    func containsFilterFilePath(vnodeID: UInt64) -> Bool {
        if vnodeID == 0 {
            return false
        }
        return filterFileList.contains(vnodeID)
    }
}
