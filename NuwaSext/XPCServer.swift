//
//  XPCConnection.swift
//  NuwaSext
//
//  Created by ConradSun on 2022/8/11.
//

import Foundation

@objc protocol ManagerXPCProtocol {
    func reportAuthEvent(authEvent: String)
    func reportNotifyEvent(notifyEvent: String)
}

@objc protocol SextXPCProtocol {
    func connectResponse(_ handler: @escaping (Bool) -> Void)
    func setLogLevel(_ level: UInt8)
    func replyAuthEvent(index: UInt64, isAllowed: Bool)
    func updateMuteList(vnodeID: [UInt64], type: UInt8)
}

class XPCServer: NSObject {
    static let shared = XPCServer()
    var nuwaLog = NuwaLog()
    var listener: NSXPCListener?
    var connection: NSXPCConnection?
    
    private func getMachServiceName(from bundle: Bundle) -> String {
        let clientKeys = bundle.object(forInfoDictionaryKey: ClientName) as? [String: Any]
        let machServiceName = clientKeys?[MachServiceKey] as? String
        return machServiceName ?? ""
    }
    
    func startListener() {
        let newListener = NSXPCListener(machServiceName: SextBundle)
        newListener.delegate = self
        newListener.resume()
        listener = newListener
        Logger(.Info, "Start XPC listener successfully.")
    }
    
    func connectToSext(bundle: Bundle, delegate: ManagerXPCProtocol, handler: @escaping (Bool) -> Void) {
        guard connection == nil else {
            Logger(.Info, "Manager already connected.")
            handler(true)
            return
        }
        guard getMachServiceName(from: bundle) == ClientBundle else {
            handler(false)
            return
        }
        
        let newConnection = NSXPCConnection(machServiceName: SextBundle)
        newConnection.exportedObject = delegate
        newConnection.exportedInterface = NSXPCInterface(with: ManagerXPCProtocol.self)
        newConnection.remoteObjectInterface = NSXPCInterface(with: SextXPCProtocol.self)
        newConnection.invalidationHandler = {
            self.connection = nil
            Logger(.Info, "Sext disconnected.")
            handler(false)
        }
        newConnection.interruptionHandler = {
            self.connection = nil
            Logger(.Error, "Sext interrupted.")
            handler(false)
        }
        connection = newConnection
        newConnection.resume()
        
        let proxy = newConnection.remoteObjectProxyWithErrorHandler { error in
            Logger(.Error, "Failed to connect with error [\(error)]")
            self.connection?.invalidate()
            self.connection = nil
            handler(false)
        } as? SextXPCProtocol
        
        proxy?.connectResponse(handler)
        handler(true)
    }
}

extension XPCServer: NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        guard connection == nil else {
            Logger(.Warning, "Manager connected already.")
            return false
        }
        
        newConnection.exportedObject = self
        newConnection.exportedInterface = NSXPCInterface(with: SextXPCProtocol.self)
        newConnection.remoteObjectInterface = NSXPCInterface(with: ManagerXPCProtocol.self)
        newConnection.invalidationHandler = {
            self.connection = nil
            Logger(.Info, "Manager disconnected.")
        }
        newConnection.interruptionHandler = {
            self.connection = nil
            Logger(.Error, "Manager interrupted.")
        }
        
        Logger(.Info, "Manager connected successfully.")
        connection = newConnection
        newConnection.resume()
        return true
    }
}
