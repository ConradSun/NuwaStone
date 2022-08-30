//
//  FlowParser.swift
//  NuwaSext
//
//  Created by ConradSun on 2022/8/29.
//

import Foundation
import NetworkExtension

extension ContentFilter {
    private func fillBasicInfo(event: inout NuwaEventInfo, type: NuwaEventType) {
        event.eventType = type
        event.eventTime = UInt64(Date().timeIntervalSince1970)
    }
    
    private func parseNetAccess(flow: NEFilterSocketFlow, event: inout NuwaEventInfo) {
        guard let local = flow.localEndpoint as? NWHostEndpoint else {
            return
        }
        guard let remote = flow.remoteEndpoint as? NWHostEndpoint else {
            return
        }
        
        flow.sourceAppAuditToken?.withUnsafeBytes({ pointer in
            guard let token = pointer.bindMemory(to: audit_token_t.self).first else {
                Logger(.Warning, "Failed to obtain audit token.")
                return
            }
            
            event.pid = audit_token_to_pid(token)
            event.setUserName(uid: audit_token_to_euid(token))
        })
        
        if flow.socketProtocol == IPPROTO_UDP {
            event.props[PropProtocol] = NuwaProtocolType.Udp.rawValue
        }
        else if flow.socketProtocol == IPPROTO_TCP {
            event.props[PropProtocol] = NuwaProtocolType.Tcp.rawValue
        }
        else {
            event.props[PropProtocol] = NuwaProtocolType.Unsupport.rawValue
        }
        
        event.props.updateValue("\(local.hostname) : \(local.port)", forKey: PropLocalAddr)
        event.props.updateValue("\(remote.hostname) : \(remote.port)", forKey: PropRemoteAddr)
    }
    
    func parseNewFlow(flow: NEFilterSocketFlow) {
        if flow.localEndpoint == nil || flow.remoteEndpoint == nil {
            return
        }
        
        var event = NuwaEventInfo()
        fillBasicInfo(event: &event, type: .NetAccess)
        parseNetAccess(flow: flow, event: &event)
        XPCServer.shared.sendNotifyEvent(event)
    }
}
