//
//  ListManager.swift
//  NuwaSext
//
//  Created by ConradSun on 2022/8/22.
//

import Foundation

class ListManager {
    static let shared = ListManager()
    private var whiteProcList = Set<String>()
    private var blackProcList = Set<String>()
    
    func addProcessPath(path: String, isWhite: Bool) {
        if isWhite {
            whiteProcList.update(with: path)
        }
        else {
            blackProcList.update(with: path)
        }
    }
    
    func containProcPath(path: String, isWhite: inout Bool) -> Bool {
        if whiteProcList.contains(path) {
            isWhite = true
            return true
        }
        if blackProcList.contains(path) {
            isWhite = false
            return true
        }
        return false
    }
}
