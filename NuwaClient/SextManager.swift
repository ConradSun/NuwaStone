//
//  SextManager.swift
//  NuwaClient
//
//  Created by ConradSun on 2022/8/15.
//

import Foundation

class SextManager {
    private let authEventQueue = DispatchQueue(label: "com.nuwastone.auth.queue")
    private let notifyEventQueue = DispatchQueue(label: "com.nuwastone.notify.queue")
    private lazy var sextProxy = XPCServer.sharedInstance.connection?.remoteObjectProxy() as? SextXPCProtocol
    var nuwaLog = NuwaLog()
    var delegate: NuwaEventProtocol?
    
    func startMonitoring() -> Bool {
        var isConnected = false
        XPCServer.sharedInstance.connectToSext(bundle: Bundle.main, delegate: self) { success in
            DispatchQueue.global().sync {
                isConnected = success
            }
        }
        
        usleep(10000)
        return isConnected
    }
    
    func stopMonitoring() -> Bool {
        let conn = XPCServer.sharedInstance.connection
        XPCServer.sharedInstance.connection = nil
        conn?.interruptionHandler = nil
        conn?.invalidationHandler = nil
        conn?.invalidate()
        
        return true
    }
}

extension SextManager: ManagerXPCProtocol {
    func decodeEventInfo(event: String, isAuth: Bool, handler: (NuwaEventInfo) -> Void) {
        let decoder = JSONDecoder()
        guard let data = event.data(using: .utf8) else {
            Logger(.Warning, "Failed to seralize event.")
            return
        }
        guard var event = try? decoder.decode(NuwaEventInfo.self, from: data) else {
            Logger(.Warning, "Failed to decode event.")
            return
        }
        if !isAuth {
            if event.eventType == .ProcessCreate {
                ProcessCache.sharedInstance.updateCache(event)
            }
            else {
                ProcessCache.sharedInstance.getFromCache(&event)
            }
        }
        
        handler(event)
    }
    
    func reportNotifyEvent(notifyEvent: String) {
        decodeEventInfo(event: notifyEvent, isAuth: false) { event in
            delegate?.displayNuwaEvent(event)
        }
    }
    
    func reportAuthEvent(authEvent: String) {
        return
    }
}
