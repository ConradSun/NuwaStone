//
//  XPCConnection.swift
//  NuwaDaemon
//
//  Created by ConradSun on 2022/7/28.
//

import Foundation

@objc protocol ClientXPCProtocol {
}

@objc protocol DaemonXPCProtocol {
    func connectResponse(_ handler: @escaping (Bool) -> Void)
    func getProcessPath(pid: Int32, eventHandler: @escaping (String, Int32) -> Void)
    func getProcessCurrentDir(pid: Int32, eventHandler: @escaping (String, Int32) -> Void)
    func getProcessArgs(pid: Int32, eventHandler: @escaping ([String], Int32) -> Void)
    func launchUninstaller()
}

class XPCConnection: NSObject {
    static let shared = XPCConnection()
    var listener: NSXPCListener?
    var connection: NSXPCConnection?
    
    private func getMachServiceName(from bundle: Bundle) -> String {
        let clientKeys = bundle.object(forInfoDictionaryKey: ClientName) as? [String: Any]
        let machServiceName = clientKeys?[MachServiceKey] as? String
        return machServiceName ?? ""
    }
    
    func startListener() {
        let newListener = NSXPCListener(machServiceName: DaemonBundle)
        newListener.delegate = self
        newListener.resume()
        listener = newListener
        Logger(.Info, "Start XPC listener successfully.")
    }
    
    func connectToDaemon(bundle: Bundle, delegate: ClientXPCProtocol, handler: @escaping (Bool) -> Void) {
        guard connection == nil else {
            Logger(.Info, "Client already connected.")
            handler(true)
            return
        }
        guard getMachServiceName(from: bundle) == ClientBundle else {
            handler(false)
            return
        }
        
        let newConnection = NSXPCConnection(machServiceName: DaemonBundle)
        newConnection.exportedObject = delegate
        newConnection.exportedInterface = NSXPCInterface(with: ClientXPCProtocol.self)
        newConnection.remoteObjectInterface = NSXPCInterface(with: DaemonXPCProtocol.self)
        connection = newConnection
        newConnection.resume()
        
        let proxy = newConnection.remoteObjectProxyWithErrorHandler { error in
            Logger(.Error, "Failed to connect with error [\(error)]")
            self.connection?.invalidate()
            self.connection = nil
            handler(false)
        } as? DaemonXPCProtocol
        
        proxy?.connectResponse(handler)
    }
}

extension XPCConnection: NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedObject = self
        newConnection.exportedInterface = NSXPCInterface(with: DaemonXPCProtocol.self)
        newConnection.remoteObjectInterface = NSXPCInterface(with: ClientXPCProtocol.self)
        newConnection.invalidationHandler = {
            self.connection = nil
            Logger(.Info, "Client disconnected.")
        }
        newConnection.interruptionHandler = {
            self.connection = nil
            Logger(.Info, "Client interrupted.")
        }
        
        connection = newConnection
        newConnection.resume()
        return true
    }
}
