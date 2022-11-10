//
//  ContentFilter.swift
//  NuwaSext
//
//  Created by ConradSun on 2022/8/26.
//

import Foundation
import NetworkExtension

class ContentFilter: NEFilterDataProvider {
    override func startFilter(completionHandler: @escaping (Error?) -> Void) {
        let ipv4LocalHost = NWHostEndpoint(hostname: "127.0.0.1", port: "0")
        let ipv4LocalNetworkRule = NENetworkRule(remoteNetwork: ipv4LocalHost, remotePrefix: 0, localNetwork: ipv4LocalHost, localPrefix: 0, protocol: .any, direction: .any)
        let ipv4LocalFilterRule = NEFilterRule(networkRule: ipv4LocalNetworkRule, action: .filterData)
        
        let ipv6LocalHost = NWHostEndpoint(hostname: "::1", port: "0")
        let ipv6LocalNetworkRule = NENetworkRule(remoteNetwork: ipv6LocalHost, remotePrefix: 0, localNetwork: ipv6LocalHost, localPrefix: 0, protocol: .any, direction: .any)
        let ipv6LocalFilterRule = NEFilterRule(networkRule: ipv6LocalNetworkRule, action: .filterData)
        
        let normalNetworkRule = NENetworkRule(remoteNetwork: nil, remotePrefix: 0, localNetwork: nil, localPrefix: 0, protocol: .any, direction: .any)
        let normalFilterRule = NEFilterRule(networkRule: normalNetworkRule, action: .filterData)
        
        let filterSettings = NEFilterSettings(rules: [ipv4LocalFilterRule, ipv6LocalFilterRule, normalFilterRule], defaultAction: .allow)
        
        apply(filterSettings) { error in
            if error != nil {
                Logger(.Error, "Failed to apply filter settings [\(error!)]")
            }
            completionHandler(error)
        }
        Logger(.Info, "Start content filter successfully.")
    }
    
    override func stopFilter(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        Logger(.Info, "Stop content filter for [\(reason)].")
        completionHandler()
    }
    
    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        guard XPCServer.shared.connection != nil else {
            return .allow()
        }
        guard let socketFlow = flow as? NEFilterSocketFlow else {
            return .allow()
        }
        guard let remote = socketFlow.remoteEndpoint as? NWHostEndpoint else {
            return .allow()
        }
        
        if socketFlow.socketProtocol == IPPROTO_TCP || socketFlow.socketProtocol == IPPROTO_UDP {
            parseNewFlow(flow: socketFlow)
        }
        if remote.port == "53" {
            return NEFilterNewFlowVerdict.filterDataVerdict(withFilterInbound: true, peekInboundBytes: Int(INT_MAX), filterOutbound: false, peekOutboundBytes: 0)
        }
        return .allow()
    }
    
    override func handleInboundData(from flow: NEFilterFlow, readBytesStartOffset offset: Int, readBytes: Data) -> NEFilterDataVerdict {
        guard let socketFlow = flow as? NEFilterSocketFlow else {
            return .allow()
        }
        parseInboundData(flow: socketFlow, data: readBytes)
        
        return .allow()
    }
}
