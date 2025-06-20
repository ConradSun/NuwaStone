//
//  XPCConnection.swift
//  NuwaDaemon
//
//  Created by ConradSun on 2022/7/28.
//

import Foundation

/// Protocol to be implemented by xpc client (nuwaclient)
@objc protocol ClientXPCProtocol {
    func connectionDidInterrupt()
    func connectionDidInvalidate()
}

/// Protocol to be implemented by xpc server (nuwadaemon)
@objc protocol DaemonXPCProtocol {
    func connectResponse(_ handler: @escaping (Bool) -> Void)
    func getProcessPath(pid: Int32, eventHandler: @escaping (String, Int32) -> Void)
    func getProcessCurrentDir(pid: Int32, eventHandler: @escaping (String, Int32) -> Void)
    func getProcessArgs(pid: Int32, eventHandler: @escaping ([String], Int32) -> Void)
    func launchUninstaller()
}

/// XPC class to be used by nuwadaemon and nuwaclient
class XPCConnection: NSObject {
    static let shared = XPCConnection()
    var listener: NSXPCListener?
    var connection: NSXPCConnection?
    weak var clientDelegate: ClientXPCProtocol?
    
    func connectToDaemon(delegate: ClientXPCProtocol, handler: @escaping (Bool) -> Void) {
        guard connection == nil else {
            Logger(.Info, "Client already connected.")
            handler(true)
            return
        }
        
        clientDelegate = delegate
        let newConnection = NSXPCConnection(machServiceName: DaemonBundle)
        newConnection.exportedObject = delegate
        newConnection.exportedInterface = NSXPCInterface(with: ClientXPCProtocol.self)
        newConnection.remoteObjectInterface = NSXPCInterface(with: DaemonXPCProtocol.self)
        
        newConnection.invalidationHandler = { [weak self] in
            guard let self = self else { return }
            self.connection = nil
            Logger(.Info, "Daemon disconnected.")
            self.clientDelegate?.connectionDidInvalidate()
            handler(false)
        }
        
        newConnection.interruptionHandler = { [weak self] in
            guard let self = self else { return }
            self.connection = nil
            Logger(.Error, "Daemon interrupted.")
            self.clientDelegate?.connectionDidInterrupt()
            handler(false)
        }
        
        connection = newConnection
        newConnection.resume()
        
        let proxy = newConnection.remoteObjectProxyWithErrorHandler { [weak self] error in
            guard let self = self else { return }
            Logger(.Error, "Failed to connect with error [\(error)]")
            self.connection?.invalidate()
            self.connection = nil
            self.clientDelegate?.connectionDidInvalidate()
            handler(false)
        } as? DaemonXPCProtocol
        
        proxy?.connectResponse(handler)
    }
}
