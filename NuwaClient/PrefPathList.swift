//
//  PrefPathList.swift
//  NuwaClient
//
//  Created by ConradSun on 2022/9/16.
//

import Foundation

class PrefPathList {
    static let shared = PrefPathList()
    
    var allowExecList = [String]()
    var denyExecList = [String]()
    var filePathsForFileMute = [String]()
    var procPathsForFileMute = [String]()
    var ipAddrsForNetMute = Set<String>()
    var procPathsForNetMute = Set<String>()
    
    init() {
        var list = UserDefaults.standard.array(forKey: UserMuteNetByProc) as? [String] ?? [String]()
        for path in list {
            procPathsForNetMute.update(with: path)
        }
        list = UserDefaults.standard.array(forKey: UserMuteNetByIP) as? [String] ?? [String]()
        for ip in list {
            ipAddrsForNetMute.update(with: ip)
        }
        
        filePathsForFileMute = UserDefaults.standard.array(forKey: UserMuteFileByFile) as? [String] ?? [String]()
        procPathsForFileMute = UserDefaults.standard.array(forKey: UserMuteFileByProc) as? [String] ?? [String]()
        
        allowExecList = UserDefaults.standard.array(forKey: UserAllowExecList) as? [String] ?? [String]()
        denyExecList = UserDefaults.standard.array(forKey: UserDenyExecList) as? [String] ?? [String]()
    }
    
    func updateMuteExecList(paths: [String], type: NuwaMuteType) {
        if type == .AllowProcExec {
            allowExecList.removeAll()
            allowExecList = paths
            UserDefaults.standard.set(allowExecList, forKey: UserAllowExecList)
        }
        else {
            denyExecList.removeAll()
            denyExecList = paths
            UserDefaults.standard.set(denyExecList, forKey: UserDenyExecList)
        }
    }
    
    func appendMuteExecList(path: String, type: NuwaMuteType) {
        if type == .AllowProcExec {
            allowExecList.append(path)
            UserDefaults.standard.set(allowExecList, forKey: UserAllowExecList)
        }
        else {
            denyExecList.append(path)
            UserDefaults.standard.set(denyExecList, forKey: UserDenyExecList)
        }
    }
    
    func updateMuteFileList(paths: [String], type: NuwaMuteType) {
        if type == .FilterFileByFilePath {
            filePathsForFileMute.removeAll()
            filePathsForFileMute = paths
            UserDefaults.standard.set(filePathsForFileMute, forKey: UserMuteFileByFile)
        }
        else {
            procPathsForFileMute.removeAll()
            procPathsForFileMute = paths
            UserDefaults.standard.set(procPathsForFileMute, forKey: UserMuteFileByProc)
        }
    }
    
    func updateMuteNetworkList(values: [String], type: NuwaMuteType) {
        if type == .FilterNetByProcPath {
            procPathsForNetMute.removeAll()
            for path in values {
                procPathsForNetMute.update(with: path)
            }
            UserDefaults.standard.set(procPathsForNetMute.sorted(), forKey: UserMuteNetByProc)
        }
        else {
            ipAddrsForNetMute.removeAll()
            for ip in values {
                procPathsForNetMute.update(with: ip)
            }
            UserDefaults.standard.set(ipAddrsForNetMute.sorted(), forKey: UserMuteNetByIP)
        }
    }
}
