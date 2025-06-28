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
    var isConnected = false
    var userPref = Preferences()
    var delegate: NuwaEventProcessProtocol?
    private let jsonDecoder = JSONDecoder()
}

extension SextManager: ManagerXPCProtocol {
    private func decodeEventInfo(eventData: Data) -> NuwaEventInfo? {
        guard let event = try? jsonDecoder.decode(NuwaEventInfo.self, from: eventData) else {
            Logger(.Warning, "Failed to decode event.")
            return nil
        }
        return event
    }
    
    func reportNotifyEvent(notifyEvent: Data) {
        guard var event = decodeEventInfo(eventData: notifyEvent) else {
            Logger(.Warning, "Failed to decode notify event.")
            return
        }
        
        if event.eventType == .ProcessCreate {
            ProcessCache.shared.updateCache(event)
        } else {
            ProcessCache.shared.getFromCache(&event)
        }
        
        delegate?.displayNotifyEvent(event)
    }
    
    func reportAuthEvent(authEvent: Data) {
        guard let event = decodeEventInfo(eventData: authEvent) else {
            Logger(.Warning, "Failed to decode auth event.")
            return
        }
        
        if userPref.auditSwitch {
            delegate?.processAuthEvent(event)
        } else {
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
    
    var isExtConnected: Bool {
        get {
            return isConnected
        }
    }
    
    func startProvider() -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        XPCServer.shared.connectToSext(delegate: self) { success in
            self.isConnected = success
            if !success {
                self.delegate?.handleBrokenConnection()
            } else {
                self.sextProxy = XPCServer.shared.connection?.remoteObjectProxy() as? SextXPCProtocol
            }
            semaphore.signal()
        }
        
        // The XPC method is called on the other thread, so we need to wait for the operation to be finished.
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
        isConnected = false
        
        return true
    }
    
    func setLogLevel(level: NuwaLogLevel) -> Bool {
        guard let proxy = sextProxy else {
            Logger(.Error, "Failed to set log level for sext, since the proxy is nil.")
            return false
        }
        proxy.setLogLevel(level.rawValue)
        NuwaLog.logLevel = level
        Logger(.Info, "Log level is setted to \(NuwaLog.logLevel)")
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
