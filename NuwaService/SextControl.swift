//
//  SextControl.swift
//  NuwaClient
//
//  Created by ConradSun on 2022/8/11.
//

import Foundation
import SystemExtensions

@available(macOS 10.16, *)
class SextControl: NSObject, OSSystemExtensionRequestDelegate {
    let controlQueue = DispatchQueue(label: "com.nuwastone.sextcontrol.queue")
    var isConnected = false
    var isFinished = false
    
    func activateExtension() {
        isConnected = false
        isFinished = false
        let request = OSSystemExtensionRequest.activationRequest(forExtensionWithIdentifier: SextBundle, queue: controlQueue)
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }
    
    func deactivateExtension() {
        isConnected = false
        isFinished = false
        let request = OSSystemExtensionRequest.deactivationRequest(forExtensionWithIdentifier: SextBundle, queue: controlQueue)
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }
    
    func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties, withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        Logger(.Info, "Replacing extension \(request.identifier) version \(existing.bundleShortVersion) with version \(ext.bundleShortVersion)")
        return .replace
    }
    
    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        Logger(.Info, "Request to control \(request.identifier) awaiting approval.")
    }
    
    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        Logger(.Info, "Request to control \(request.identifier) succeeded [\(result)].")
        isConnected = true
        isFinished = true
    }
    
    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        Logger(.Info, "Request to control \(request.identifier) failed [\(error)].")
        isFinished = true
    }
}
