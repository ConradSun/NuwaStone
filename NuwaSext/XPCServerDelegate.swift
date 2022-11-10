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
    
    func replyAuthEvent(index: UInt64, isAllowed: Bool) {
        ResponseManager.shared.replyAuthEvent(index: index, isAllowed: isAllowed)
    }
    
    func updateMuteList(vnodeID: UInt64, type: UInt8, opt: UInt8) {
        let muteType = NuwaMuteType(rawValue: type)
        let optType = NuwaPrefOpt(rawValue: opt)
        switch muteType {
        case .AllowExec:
            if optType == .Add {
                ListManager.shared.updateAuthProcList(vnodeID: vnodeID, isWhite: true)
            }
            else if optType == .Remove {
                ListManager.shared.removeAuthProcPath(vnodeID: vnodeID, isWhite: true)
            }
        case .DenyExec:
            if optType == .Add {
                ListManager.shared.updateAuthProcList(vnodeID: vnodeID, isWhite: false)
            }
            else if optType == .Remove {
                ListManager.shared.removeAuthProcPath(vnodeID: vnodeID, isWhite: false)
            }
        case .FilterFileEvent:
            if optType == .Add {
                ListManager.shared.updateFilterFileList(vnodeID: vnodeID)
            }
            else if optType == .Remove {
                ListManager.shared.removeFilterFilePath(vnodeID: vnodeID)
            }
            break
        case .FilterNetEvent:
            break
        default:
            break
        }
    }
}
