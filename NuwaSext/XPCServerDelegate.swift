//
//  XPCServerDelegate.swift
//  NuwaSext
//
//  Created by ConradSun on 2022/8/18.
//

import AppKit
import Foundation

extension XPCServer {
    /// Called to start the xpc listener
    func startListener() {
        let newListener = NSXPCListener(machServiceName: SextBundle)
        newListener.delegate = self
        newListener.resume()
        listener = newListener
        Logger(.Info, "Start XPC listener successfully.")
    }
    
    /// Called to encode event info into json
    /// - Parameter event: Event to be encoded
    /// - Returns: Event json
    func encodeEventInfo(_ event: NuwaEventInfo) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        guard let data = try? encoder.encode(event) else {
            Logger(.Warning, "Failed to seralize event.")
            return ""
        }
        guard let json = String(data: data, encoding: .utf8) else {
            Logger(.Warning, "Failed to encode event json.")
            return ""
        }
        
        return json
    }
    
    /// Called to send auth event to the nuwa client
    /// - Parameter event: Event to be sent
    /// - Returns: false for failed, true for succeed
    func sendAuthEvent(_ event: NuwaEventInfo) ->Bool {
        guard let proxy = connection?.remoteObjectProxy as? ManagerXPCProtocol else {
            return false
        }
        let json = encodeEventInfo(event)
        if !json.isEmpty {
            proxy.reportAuthEvent(authEvent: json)
            return true
        }
        return false
    }
    
    /// Called to send notify event to the nuwa client
    /// - Parameter event: Event to be sent
    func sendNotifyEvent(_ event: NuwaEventInfo) {
        let proxy = connection?.remoteObjectProxy as? ManagerXPCProtocol
        let json = encodeEventInfo(event)
        if !json.isEmpty {
            proxy?.reportNotifyEvent(notifyEvent: json)
        }
    }
}

extension XPCServer: NSXPCListenerDelegate {
    /// Called when a new incoming connection request received
    /// - Parameters:
    ///   - listener: XPC listener (unused)
    ///   - newConnection: Connection to be configured/accepted/resumed
    /// - Returns: false when not accepted, true when accepted
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        guard connection == nil else {
            Logger(.Warning, "Manager connected already.")
            return false
        }
        
        if !verifyXPCPeer(pid: newConnection.processIdentifier) {
            Logger(.Error, "Failed to verify the peer.")
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
    
    /// Called to verify the xpc peer
    /// - Parameter pid: Peer pid
    /// - Returns: false for not passing the verification, true for passing
    private func verifyXPCPeer(pid: pid_t) -> Bool {
        guard let peerAPP = NSRunningApplication(processIdentifier: pid) else {
            return false
        }
        guard let bundleURL = peerAPP.bundleURL else {
            return false
        }
        guard let peerBundle = Bundle(url: bundleURL) else {
            return false
        }
        
        let peerName = getMachServiceName(from: peerBundle)
        return peerName == ClientBundle
    }
    
    /// Called to get mach service name
    /// - Parameter bundle: APP bundle
    /// - Returns: Mach service name
    private func getMachServiceName(from bundle: Bundle) -> String {
        let clientKeys = bundle.object(forInfoDictionaryKey: ClientName) as? [String: Any]
        let machServiceName = clientKeys?[MachServiceKey] as? String
        return machServiceName ?? ""
    }
}

extension XPCServer: SextXPCProtocol {
    func connectResponse(_ handler: @escaping (Bool) -> Void) {
        Logger(.Info, "Manager connected.")
        handler(true)
    }
    
    func setLogLevel(_ level: UInt8) {
        nuwaLog.logLevel = level
        Logger(.Info, "Log level is setted to \(nuwaLog.logLevel)")
    }
    
    func replyAuthEvent(index: UInt64, isAllowed: Bool) {
        ResponseManager.shared.replyAuthEvent(index: index, isAllowed: isAllowed)
    }
    
    func updateMuteList(vnodeID: [UInt64], type: UInt8) {
        guard let muteType = NuwaMuteType(rawValue: type) else {
            return
        }
        
        switch muteType {
        case .FilterFileByFilePath, .FilterFileByProcPath:
            ListManager.shared.updateFilterFileList(vnodeID: vnodeID, type: muteType)
            
        case .AllowProcExec, .DenyProcExec:
            ListManager.shared.updateAuthProcList(vnodeID: vnodeID, type: muteType)
            
        default:
            break
        }
    }
}
