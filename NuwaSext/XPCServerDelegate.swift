//
//  XPCServerDelegate.swift
//  NuwaSext
//
//  Created by ConradSun on 2022/8/18.
//

import Foundation


extension XPCServer {
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
    
    func sendAuthEvent(_ event: NuwaEventInfo) {
        let proxy = connection?.remoteObjectProxy as? ManagerXPCProtocol
        let json = encodeEventInfo(event)
        if !json.isEmpty {
            proxy?.reportAuthEvent(authEvent: json)
        }
    }
    
    func sendNotifyEvent(_ event: NuwaEventInfo) {
        let proxy = connection?.remoteObjectProxy as? ManagerXPCProtocol
        let json = encodeEventInfo(event)
        if !json.isEmpty {
            proxy?.reportNotifyEvent(notifyEvent: json)
        }
    }
}

extension XPCServer: SextXPCProtocol {
    func connectResponse(_ handler: @escaping (Bool) -> Void) {
        Logger(.Info, "Manager connected.")
        handler(true)
    }
    
    func setLogLevel(_ level: UInt8) {
        nuwaLog.logLevel = level
        Logger(.Info, "Log level is setted to \(nuwaLog)")
    }
    
    func replyAuthEvent(pointer: UInt, isAllowed: Bool) {
        ResponseManager.shared.replyAuthEvent(pointer: pointer, isAllowed: isAllowed)
    }
    
    func addProcessPath(path: String, isWhite: Bool) {
        ListManager.shared.addProcessPath(path: path, isWhite: isWhite)
    }
}
