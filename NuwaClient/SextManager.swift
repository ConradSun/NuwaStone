//
//  SextManager.swift
//  NuwaClient
//
//  Created by ConradSun on 2022/8/15.
//

import Foundation

class SextManager {
    private lazy var sextProxy = XPCServer.shared.connection?.remoteObjectProxy() as? SextXPCProtocol
    static let shared = SextManager()
    var nuwaLog = NuwaLog()
    var delegate: NuwaEventProcessProtocol?
}

extension SextManager: ManagerXPCProtocol {
    private func decodeEventInfo(event: String, isAuth: Bool) -> NuwaEventInfo? {
        let decoder = JSONDecoder()
        guard let data = event.data(using: .utf8) else {
            Logger(.Warning, "Failed to seralize event.")
            return nil
        }
        guard var event = try? decoder.decode(NuwaEventInfo.self, from: data) else {
            Logger(.Warning, "Failed to decode event.")
            return nil
        }
        if !isAuth {
            if event.eventType == .ProcessCreate {
                ProcessCache.shared.updateCache(event)
            }
            else {
                ProcessCache.shared.getFromCache(&event)
            }
        }
        
        return event
    }
    
    func reportNotifyEvent(notifyEvent: String) {
        guard let event = decodeEventInfo(event: notifyEvent, isAuth: false) else {
            return
        }
        delegate?.displayNotifyEvent(event)
    }
    
    func reportAuthEvent(authEvent: String) {
        guard let event = decodeEventInfo(event: authEvent, isAuth: true) else {
            return
        }
        
        if event.eventType == .ProcessCreate {
            if event.props[PropCodeSign] != nil {
                _ = replyAuthEvent(eventID: event.eventID, isAllowed: true)
                return
            }
        }
        delegate?.processAuthEvent(event)
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
            semaphore.signal()
        }
        
        semaphore.wait()
        return isConnected
    }
    
    func stopProvider() -> Bool {
        let conn = XPCServer.shared.connection
        XPCServer.shared.connection = nil
        conn?.interruptionHandler = nil
        conn?.invalidationHandler = nil
        conn?.invalidate()
        
        return true
    }
    
    func setLogLevel(level: UInt8) -> Bool {
        nuwaLog.logLevel = level
        sextProxy?.setLogLevel(level)
        Logger(.Info, "Log level is setted to \(nuwaLog)")
        return true
    }
    
    func replyAuthEvent(eventID: UInt64, isAllowed: Bool) -> Bool {
        if eventID == 0 {
            return false
        }
        sextProxy?.replyAuthEvent(pointer: UInt(eventID), isAllowed: isAllowed)
        return true
    }
    
    func udpateMuteList(vnodeID: UInt64, type: NuwaMuteType, opt: NuwaPrefOpt) -> Bool {
        if vnodeID == 0 {
            return false
        }
        sextProxy?.updateMuteList(vnodeID: vnodeID, type: type.rawValue, opt: opt.rawValue)
        return true
    }
}
