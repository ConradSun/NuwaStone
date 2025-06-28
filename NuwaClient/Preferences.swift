//
//  Preferences.swift
//  NuwaClient
//
//  Created by ConradSun on 2022/9/16.
//

import Foundation

/// User preferences based on UserDefaults
struct Preferences {
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            UserAuditSwitch: false,
            UserClearDuration: 360.0,
            UserAllowExecList: [String](),
            UserDenyExecList: [String](),
            UserMuteFileByFile: [String](),
            UserMuteFileByProc: [String](),
            UserMuteNetByProc: [String](),
            UserMuteNetByIP: [String]()
        ])
    }
    
    private var _auditSwitch: Bool
    private var _clearDuration: TimeInterval
    private var _allowExecList: [String]
    private var _denyExecList: [String]
    private var _filePathsForFileMute: [String]
    private var _procPathsForFileMute: [String]
    private var _procPathsForNetMute: Set<String>
    private var _ipAddrsForNetMute: Set<String>

    init() {
        Preferences.registerDefaults()
        _auditSwitch = UserDefaults.standard.bool(forKey: UserAuditSwitch)
        let duration = UserDefaults.standard.double(forKey: UserClearDuration)
        _clearDuration = duration >= 0 ? duration : 360
        _allowExecList = UserDefaults.standard.array(forKey: UserAllowExecList) as? [String] ?? [String]()
        _denyExecList = UserDefaults.standard.array(forKey: UserDenyExecList) as? [String] ?? [String]()
        _filePathsForFileMute = UserDefaults.standard.array(forKey: UserMuteFileByFile) as? [String] ?? [String]()
        _procPathsForFileMute = UserDefaults.standard.array(forKey: UserMuteFileByProc) as? [String] ?? [String]()
        let netProc = UserDefaults.standard.array(forKey: UserMuteNetByProc) as? [String] ?? [String]()
        _procPathsForNetMute = Set(netProc)
        let netIP = UserDefaults.standard.array(forKey: UserMuteNetByIP) as? [String] ?? [String]()
        _ipAddrsForNetMute = Set(netIP)
    }
    
    var auditSwitch: Bool {
        get { _auditSwitch }
        set {
            _auditSwitch = newValue
            UserDefaults.standard.set(newValue, forKey: UserAuditSwitch)
        }
    }
    
    var clearDuration: TimeInterval {
        get { _clearDuration }
        set {
            _clearDuration = newValue
            UserDefaults.standard.set(newValue, forKey: UserClearDuration)
        }
    }
    
    var allowExecList: [String] {
        get { _allowExecList }
        set {
            _allowExecList = newValue
            UserDefaults.standard.set(newValue, forKey: UserAllowExecList)
        }
    }
    
    var denyExecList: [String] {
        get { _denyExecList }
        set {
            _denyExecList = newValue
            UserDefaults.standard.set(newValue, forKey: UserDenyExecList)
        }
    }
    
    var filePathsForFileMute: [String] {
        get { _filePathsForFileMute }
        set {
            _filePathsForFileMute = newValue
            UserDefaults.standard.set(newValue, forKey: UserMuteFileByFile)
        }
    }
    
    var procPathsForFileMute: [String] {
        get { _procPathsForFileMute }
        set {
            _procPathsForFileMute = newValue
            UserDefaults.standard.set(newValue, forKey: UserMuteFileByProc)
        }
    }
    
    var procPathsForNetMute: Set<String> {
        get { _procPathsForNetMute }
        set {
            _procPathsForNetMute = newValue
            UserDefaults.standard.set(newValue.sorted(), forKey: UserMuteNetByProc)
        }
    }
    
    var ipAddrsForNetMute: Set<String> {
        get { _ipAddrsForNetMute }
        set {
            _ipAddrsForNetMute = newValue
            UserDefaults.standard.set(newValue.sorted(), forKey: UserMuteNetByIP)
        }
    }
}
