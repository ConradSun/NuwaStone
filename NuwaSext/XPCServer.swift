//
//  XPCConnection.swift
//  NuwaSext
//
//  Created by ConradSun on 2022/8/11.
//

import Foundation


/// Protocol to be implemented by xpc client (nuwaclient)
@objc protocol ManagerXPCProtocol {
    func reportAuthEvent(authEvent: String)
    func reportNotifyEvent(notifyEvent: String)
}

/// Protocol to be implemented by xpc server (nuwasext)
@objc protocol SextXPCProtocol {
    func connectResponse(_ handler: @escaping (Bool) -> Void)
    func setLogLevel(_ level: UInt8)
    func replyAuthEvent(index: UInt64, isAllowed: Bool)
    func updateMuteList(vnodeID: [UInt64], type: UInt8)
}

/// XPC class to be used by nuwasext and nuwaclient
class XPCServer: NSObject {
    static let shared = XPCServer()
    var nuwaLog = NuwaLog()
    var listener: NSXPCListener?
    var connection: NSXPCConnection?
    
    /// Called to send request to connect to the sext (only called by the xpc client)
    /// - Parameters:
    ///   - delegate: Delegate to process sext request
    ///   - handler: Code block to process result
    func connectToSext(delegate: ManagerXPCProtocol, handler: @escaping (Bool) -> Void) {
        guard connection == nil else {
            Logger(.Info, "Manager already connected.")
            handler(true)
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
