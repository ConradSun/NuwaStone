//
//  XPCConnection.swift
//  NuwaSext
//
//  Created by ConradSun on 2022/8/11.
//

import Foundation


/// Protocol to be implemented by xpc client (nuwaclient)
@objc protocol ManagerXPCProtocol {
    func reportAuthEvent(authEvent: Data)
    func reportNotifyEvent(notifyEvent: Data)
}

/// Protocol to be implemented by xpc server (nuwasext)
@objc protocol SextXPCProtocol {
    func connectResponse(_ handler: @escaping (Bool) -> Void)
    func setLogLevel(_ level: UInt8)
    func replyAuthEvent(index: UInt64, isAllowed: Bool)
    func updateMuteList(vnodeID: [UInt64], type: UInt8)
}

/// Connect phases. All connection events are serialized on stateQueue, so an
/// event takes effect only when the current phase makes it relevant and any
/// duplicate or late event is dropped naturally without extra locking.
enum ConnectPhase { case idle, connecting, connected }

/// XPC class to be used by nuwasext and nuwaclient
class XPCServer: NSObject {
    static let shared = XPCServer()
    var listener: NSXPCListener?
    var connection: NSXPCConnection?

    private let stateQueue = DispatchQueue(label: "com.nuwastone.xpc.connect")
    private var connectPhase: ConnectPhase = .idle

    /// Called to send request to connect to the sext (only called by the xpc client)
    /// - Parameters:
    ///   - delegate: Delegate to process sext request
    ///   - handler: Code block to process handshake result, invoked exactly once
    ///   - onDisconnect: Code block invoked at most once when an established connection is lost
    func connectToSext(delegate: ManagerXPCProtocol, handler: @escaping (Bool) -> Void, onDisconnect: @escaping () -> Void) {
        let newConnection = NSXPCConnection(machServiceName: SextBundle)
        newConnection.exportedObject = delegate
        newConnection.exportedInterface = NSXPCInterface(with: ManagerXPCProtocol.self)
        newConnection.remoteObjectInterface = NSXPCInterface(with: SextXPCProtocol.self)
        newConnection.invalidationHandler = {
            Logger(.Info, "Sext disconnected.")
            self.handleConnectEvent(conn: newConnection, connected: false, handler: handler, onDisconnect: onDisconnect)
        }
        newConnection.interruptionHandler = {
            Logger(.Error, "Sext interrupted.")
            self.handleConnectEvent(conn: newConnection, connected: false, handler: handler, onDisconnect: onDisconnect)
        }

        var already = false
        stateQueue.sync {
            if connectPhase == .idle {
                connectPhase = .connecting
                connection = newConnection
            } else {
                already = true
            }
        }
        if already {
            Logger(.Info, "Manager already connected.")
            handler(true)
            return
        }

        newConnection.resume()
        let proxy = newConnection.remoteObjectProxyWithErrorHandler { error in
            Logger(.Error, "Failed to connect with error [\(error)]")
            newConnection.invalidate()
        } as? SextXPCProtocol

        if let proxy = proxy {
            proxy.connectResponse { success in
                self.handleConnectEvent(conn: newConnection, connected: success, handler: handler, onDisconnect: onDisconnect)
            }
        } else {
            newConnection.invalidate()
        }
    }

    /// Called to tear down the XPC connection (only called by the xpc client).
    /// Goes through the state queue so connectPhase is reset alongside connection,
    /// otherwise a subsequent connectToSext would see a non-idle phase and skip
    /// rebuilding the connection.
    func disconnectFromSext() {
        var conn: NSXPCConnection?
        stateQueue.sync {
            conn = connection
            connectPhase = .idle
            connection = nil
        }
        conn?.interruptionHandler = nil
        conn?.invalidationHandler = nil
        conn?.invalidate()
    }

    /// Apply a connection event to the phase machine; events from a torn-down
    /// connection or after the phase has moved on are dropped here.
    private func handleConnectEvent(conn: NSXPCConnection, connected: Bool, handler: @escaping (Bool) -> Void, onDisconnect: @escaping () -> Void) {
        stateQueue.async {
            guard self.connection === conn else { return }
            switch self.connectPhase {
            case .connecting:
                if connected {
                    self.connectPhase = .connected
                } else {
                    self.connectPhase = .idle
                    self.connection = nil
                }
                handler(connected)
            case .connected where !connected:
                self.connectPhase = .idle
                self.connection = nil
                onDisconnect()
            case .connected, .idle:
                break
            }
        }
    }
}
