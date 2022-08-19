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
    func replyAuthEvent(pointer: UInt, isAllowed: Bool)
}

class XPCServer: NSObject {
    static let shared = XPCServer()
    var listener: NSXPCListener?
    var connection: NSXPCConnection?
    var delegate: ManagerXPCProtocol?
    
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
        NSLog("Start XPC listener successfully.")
    }
    
    func connectToSext(bundle: Bundle, delegate: ManagerXPCProtocol, handler: @escaping (Bool) -> Void) {
        self.delegate = delegate
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
    }
}

extension XPCServer: NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
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
        
        connection = newConnection
        newConnection.resume()
        return true
    }
}
