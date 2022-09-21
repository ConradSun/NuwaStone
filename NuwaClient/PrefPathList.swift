//
//  PrefPathList.swift
//  NuwaClient
//
//  Created by ConradSun on 2022/9/16.
//

import Foundation

class PrefPathList {
    static let shared = PrefPathList()
    var authExecDict = [String: Bool]()
    var filterFileList = Set<String>()
    var filterNetworkList = Set<String>()
    
    init() {
        var list = UserDefaults.standard.array(forKey: UserFilterFile) as? [String] ?? [String]()
        for path in list {
            filterFileList.update(with: path)
        }
        list = UserDefaults.standard.array(forKey: UserFilterNet) as? [String] ?? [String]()
        for path in list {
            filterNetworkList.update(with: path)
        }
        authExecDict = UserDefaults.standard.dictionary(forKey: UserAuthExec) as? [String : Bool] ?? [String: Bool]()
    }
    
    func updateExecList(paths: [String], opt: NuwaPrefOpt, isWhite: Bool) {
        if opt == .Add {
            for path in paths {
                authExecDict[path] = isWhite
            }
        }
        else if opt == .Remove {
            for path in paths {
                authExecDict[path] = nil
            }
        }
        UserDefaults.standard.set(authExecDict, forKey: UserAuthExec)
    }
    
    func updateWhiteFileList(paths: [String], opt: NuwaPrefOpt) {
        if opt == .Add {
            for path in paths {
                filterFileList.update(with: path)
            }
        }
        else {
            for path in paths {
                filterFileList.remove(path)
            }
        }
        UserDefaults.standard.set(filterFileList.sorted(), forKey: UserFilterFile)
    }
    
    func updateWhiteNetworkList(paths: [String], opt: NuwaPrefOpt) {
        if opt == .Add {
            for path in paths {
                filterNetworkList.update(with: path)
            }
        }
        else {
            for path in paths {
                filterNetworkList.remove(path)
            }
        }
        UserDefaults.standard.set(filterNetworkList.sorted(), forKey: UserFilterNet)
    }
}
