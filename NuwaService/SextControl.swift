//
//  SextControl.swift
//  NuwaClient
//
//  Created by ConradSun on 2022/8/11.
//

import Foundation
import SystemExtensions
import NetworkExtension

@available(macOS 11.0, *)
class SextControl: NSObject, OSSystemExtensionRequestDelegate {
    static let shared = SextControl()
    let controlQueue = DispatchQueue(label: "com.nuwastone.sextcontrol.queue")
    var toActivate = false
    
    func activateExtension() {
        toActivate = true
        let request = OSSystemExtensionRequest.activationRequest(forExtensionWithIdentifier: SextBundle, queue: controlQueue)
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }
    
    func deactivateExtension() {
        toActivate = false
        let request = OSSystemExtensionRequest.deactivationRequest(forExtensionWithIdentifier: SextBundle, queue: controlQueue)
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }
    
    func getExtensionStatus() -> Bool {
        guard let result = launchTask(path: "/usr/bin/systemextensionsctl", args: ["list"]) else {
            return false
        }
        
        let lines = result.split(separator: "\n")
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if trimmedLine.contains(SextBundle.lowercased()) && trimmedLine.contains("[activated enabled]") {
                return true
            }
        }
        
        return false
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
        controlQueue.async {
            SextControl.shared.switchNEStatus(self.toActivate) { success in
                if !success {
                    Logger(.Error, "Failed to set network extension.")
                } else {
                    Logger(.Info, "Set network extension successfully.")
                }
            }
        }
    }
    
    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        Logger(.Error, "Request to control \(request.identifier) failed [\(error)].")
    }
}

@available(macOS 11.0, *)
extension SextControl {
    func switchNEStatus(_ enable: Bool, completion: @escaping (Bool) -> Void) {
        let manager = NEFilterManager.shared()
        let managerQueue = DispatchQueue.global(qos: .userInitiated)
        
        managerQueue.async {
            manager.loadFromPreferences { error in
                if let error = error {
                    Logger(.Error, "Failed to load preferences for network extension [\(error)]")
                    completion(false)
                    return
                }
                
                if enable {
                    Logger(.Info, "Activate network extension now...")
                    if manager.providerConfiguration == nil {
                        let config = NEFilterProviderConfiguration()
                        config.username = "NuwaService"
                        config.organization = "NuwaStone"
                        config.filterPackets = false
                        config.filterSockets = true
                        manager.providerConfiguration = config
                    }
                    manager.isEnabled = true
                } else {
                    Logger(.Info, "Deactivate network extension now...")
                    manager.isEnabled = false
                }
                
                manager.saveToPreferences { error in
                    if let error = error {
                        Logger(.Error, "Failed to save preferences for network extension [\(error)]")
                        completion(false)
                    } else {
                        completion(true)
                    }
                }
            }
        }
    }
}
