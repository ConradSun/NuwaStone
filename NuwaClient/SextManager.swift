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
            if success {
                self.sextProxy = XPCServer.shared.connection?.remoteObjectProxyWithErrorHandler({ error in
                    Logger(.Error, "Sext proxy error [\(error)]")
                }) as? SextXPCProtocol
            }
            // Deriving from sextProxy neutralizes stale success replies
            // after the connection has already been torn down.
            self.isConnected = success && self.sextProxy != nil
            semaphore.signal()
        } onDisconnect: {
            // During the handshake failure handler(false) already covers it;
            // only an established connection loss resets the UI.
            guard self.isConnected else {
                return
            }
            self.sextProxy = nil
            self.isConnected = false
            self.delegate?.handleBrokenConnection()
        }

        // The XPC method is called on the other thread, so we need to wait for the operation to be finished.
        if semaphore.wait(timeout: .now() + .milliseconds(MaxConnectWaitTime)) == .timedOut {
            Logger(.Error, "Timeout to wait for connecting the sext.")
            _ = stopProvider()
            return false
        }
        return isConnected
    }
    
    func stopProvider() -> Bool {
        XPCServer.shared.disconnectFromSext()
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
        guard eventID != 0, let proxy = sextProxy else {
            return false
        }
        proxy.replyAuthEvent(index: eventID, isAllowed: isAllowed)
        return true
    }
    
    func udpateMuteList(list: [String], type: NuwaMuteType) -> Bool {
        guard let proxy = sextProxy else {
            return false
        }
        var vnodeList = [UInt64]()
        for path in list {
            vnodeList.append(getFileVnodeID(path))
        }
        proxy.updateMuteList(vnodeID: vnodeList, type: type.rawValue)
        return true
    }
}
