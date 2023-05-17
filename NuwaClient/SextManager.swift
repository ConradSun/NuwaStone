//
//  SextManager.swift
//  NuwaClient
//
//  Created by ConradSun on 2022/8/15.
//

import Foundation

class SextManager {
    private var sextProxy: SextXPCProtocol?
    static let shared = SextManager()
    var nuwaLog = NuwaLog()
    var auditSwitch = (UserDefaults.standard.integer(forKey: UserAuditSwitch) != 0)
    var delegate: NuwaEventProcessProtocol?
}

extension SextManager: ManagerXPCProtocol {
    private func decodeEventInfo(event: String) -> NuwaEventInfo? {
        let decoder = JSONDecoder()
        guard let data = event.data(using: .utf8) else {
            Logger(.Warning, "Failed to seralize event.")
            return nil
        }
        guard let event = try? decoder.decode(NuwaEventInfo.self, from: data) else {
            Logger(.Warning, "Failed to decode event.")
            return nil
        }
        return event
    }
    
    func reportNotifyEvent(notifyEvent: String) {
        guard var event = decodeEventInfo(event: notifyEvent) else {
            Logger(.Warning, "Failed to decode notify event.")
            return
        }
        
        if event.eventType == .ProcessCreate {
            ProcessCache.shared.updateCache(event)
        }
        else {
            ProcessCache.shared.getFromCache(&event)
        }
        
        delegate?.displayNotifyEvent(event)
    }
    
    func reportAuthEvent(authEvent: String) {
        guard let event = decodeEventInfo(event: authEvent) else {
            Logger(.Warning, "Failed to decode auth event.")
            return
        }
        
        if auditSwitch {
            delegate?.processAuthEvent(event)
        }
        else {
            _ = replyAuthEvent(eventID: event.eventID, isAllowed: true)
        }
    }
}

extension SextManager: NuwaEventProviderProtocol {
    var processDelegate: NuwaEventProcessProtocol? {
        get {
            return delegate
        }
        set {
            delegate = newValue
        }
    }
    
    func startProvider() -> Bool {
        var isConnected = false
        let semaphore = DispatchSemaphore(value: 0)
        XPCServer.shared.connectToSext(bundle: Bundle.main, delegate: self) { success in
            isConnected = success
            if !success {
                self.delegate?.handleBrokenConnection()
            }
            else {
                self.sextProxy = XPCServer.shared.connection?.remoteObjectProxy() as? SextXPCProtocol
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        isConnected = sextProxy != nil
        return isConnected
    }
    
    func stopProvider() -> Bool {
        let conn = XPCServer.shared.connection
        XPCServer.shared.connection = nil
        conn?.interruptionHandler = nil
        conn?.invalidationHandler = nil
        conn?.invalidate()
        sextProxy = nil
        
        return true
    }
    
    func setLogLevel(level: UInt8) -> Bool {
        nuwaLog.logLevel = level
        sextProxy!.setLogLevel(level)
        Logger(.Info, "Log level is setted to \(nuwaLog.logLevel)")
        return true
    }
    
    func setAuditSwitch(status: Bool) -> Bool {
        auditSwitch = status
        return true
    }
    
    func replyAuthEvent(eventID: UInt64, isAllowed: Bool) -> Bool {
        if eventID == 0 {
            return false
        }
        sextProxy!.replyAuthEvent(index: eventID, isAllowed: isAllowed)
        return true
    }
    
    func udpateMuteList(list: [String], type: NuwaMuteType) -> Bool {
        var vnodeList = [UInt64]()
        for path in list {
            vnodeList.append(getFileVnodeID(path))
        }
        sextProxy!.updateMuteList(vnodeID: vnodeList, type: type.rawValue)
        return true
    }
}
