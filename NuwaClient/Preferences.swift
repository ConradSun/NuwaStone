//
//  Preferences.swift
//  NuwaClient
//
//  Created by ConradSun on 2022/9/16.
//

import Foundation

/// User preferences based on UserDefaults
struct Preferences {
    var auditSwitch: Bool {
        get {
            return UserDefaults.standard.bool(forKey: UserAuditSwitch)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserAuditSwitch)
        }
    }
    
    var clearDuration: TimeInterval {
        get {
            let duration = UserDefaults.standard.double(forKey: UserClearDuration)
            if duration >= 0 {
                return duration
            }
            return 360
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserClearDuration)
        }
    }
    
    var allowExecList: Array<String> {
        get {
            return UserDefaults.standard.array(forKey: UserAllowExecList) as? [String] ?? [String]()
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserAllowExecList)
        }
    }
    
    var denyExecList: Array<String> {
        get {
            return UserDefaults.standard.array(forKey: UserDenyExecList) as? [String] ?? [String]()
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserDenyExecList)
        }
    }
    
    var filePathsForFileMute: Array<String> {
        get {
            return UserDefaults.standard.array(forKey: UserMuteFileByFile) as? [String] ?? [String]()
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserMuteFileByFile)
        }
    }
    
    var procPathsForFileMute: Array<String> {
        get {
            return UserDefaults.standard.array(forKey: UserMuteFileByProc) as? [String] ?? [String]()
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserMuteFileByProc)
        }
    }
    
    var procPathsForNetMute: Set<String> {
        get {
            let list = UserDefaults.standard.array(forKey: UserMuteNetByProc) as? [String] ?? [String]()
            var muteSet = Set<String>()
            for path in list {
                muteSet.update(with: path)
            }
            return muteSet
        }
        set {
            UserDefaults.standard.set(newValue.sorted(), forKey: UserMuteNetByProc)
        }
    }
    
    var ipAddrsForNetMute: Set<String> {
        get {
            let list = UserDefaults.standard.array(forKey: UserMuteNetByIP) as? [String] ?? [String]()
            var muteSet = Set<String>()
            for path in list {
                muteSet.update(with: path)
            }
            return muteSet
        }
        set {
            UserDefaults.standard.set(newValue.sorted(), forKey: UserMuteNetByIP)
        }
    }
}
