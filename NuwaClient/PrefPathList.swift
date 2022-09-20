//
//  PrefPathList.swift
//  NuwaClient
//
//  Created by ConradSun on 2022/9/16.
//

import Foundation

class PrefPathList {
    static let shared = PrefPathList()
    var allowExecList = Set<String>()
    var denyExecList = Set<String>()
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
        list = UserDefaults.standard.array(forKey: UserAllowExec) as? [String] ?? [String]()
        for path in list {
            allowExecList.update(with: path)
        }
        list = UserDefaults.standard.array(forKey: UserDenyExec) as? [String] ?? [String]()
        for path in list {
            denyExecList.update(with: path)
        }
    }
    
    func updateExecList(paths: [String], opt: NuwaPrefOpt, isWhite: Bool) {
        if isWhite {
            for path in paths {
                if opt == .Add {
                    allowExecList.update(with: path)
                }
                else if opt == .Remove {
                    allowExecList.remove(path)
                }
            }
            UserDefaults.standard.set(allowExecList.sorted(), forKey: UserAllowExec)
        }
        else {
            for path in paths {
                if opt == .Add {
                    denyExecList.update(with: path)
                }
                else if opt == .Remove {
                    denyExecList.remove(path)
                }
            }
            UserDefaults.standard.set(denyExecList.sorted(), forKey: UserDenyExec)
        }
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
