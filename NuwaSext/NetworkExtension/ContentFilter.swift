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
        let networkRule = NENetworkRule(remoteNetwork: nil, remotePrefix: 0, localNetwork: nil, localPrefix: 0, protocol: .any, direction: .any)
        let filterRule = NEFilterRule(networkRule: networkRule, action: .filterData)
        let filterSettings = NEFilterSettings(rules: [filterRule], defaultAction: .allow)
        
        apply(filterSettings) { error in
            if error != nil {
                Logger(.Error, "Failed to apply filter settings [\(error!)]")
            }
            completionHandler(error)
        }
        Logger(.Info, "Start content filter successfully.")
    }
    
    override func stopFilter(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        Logger(.Info, "Stop content filter for \(reason).")
        completionHandler()
    }
    
    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        let socketFlow = flow as! NEFilterSocketFlow
        if socketFlow.localEndpoint != nil && socketFlow.remoteEndpoint != nil {
            Logger(.Info, "Flow \(socketFlow.localEndpoint!) -> \(socketFlow.remoteEndpoint!)")
        }
        
        return .allow()
    }
}
