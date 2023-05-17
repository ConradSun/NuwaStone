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
        let task = Process()
        let pipe = Pipe()
        
        task.arguments = ["list"]
        task.standardOutput = pipe
        task.launchPath = "/usr/bin/systemextensionsctl"
        task.launch()
        
        let output = try! pipe.fileHandleForReading.readToEnd()!
        guard let result = String(data: output, encoding: .utf8) else {
            return false
        }
        
        let sextList = result.split(separator: "\n")
        for sextItem in sextList {
            let sextInfo = sextItem.lowercased()
            if sextInfo.contains(SextBundle) && sextInfo.hasSuffix("[activated enabled]") {
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
            if !self.switchNEStatus(self.toActivate) {
                Logger(.Error, "Failed to activate network extension.")
                exit(EXIT_FAILURE)
            }
            else {
                Logger(.Info, "Activate network extension successfully.")
            }
        }
    }
    
    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        Logger(.Info, "Request to control \(request.identifier) failed [\(error)].")
        exit(EXIT_FAILURE)
    }
}

@available(macOS 11.0, *)
extension SextControl {
    func switchNEStatus(_ enable: Bool) -> Bool {
        let manager = NEFilterManager.shared()
        let semaphore = DispatchSemaphore(value: 0)
        let managerQueue = DispatchQueue(label: "com.nuwastone.necontrol.queue", qos: .background)
        var isError = false
        
        managerQueue.async {
            manager.loadFromPreferences { error in
                if error != nil {
                    isError = true
                    Logger(.Error, "Failed to load preferences for network extension [\(error!)]")
                }
                semaphore.signal()
            }
        }
        if semaphore.wait(timeout: .distantFuture) == .timedOut || isError {
            return false
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
        }
        else {
            Logger(.Info, "Deactivate network extension now...")
            manager.isEnabled = false
        }
        
        isError = false
        managerQueue.async {
            manager.saveToPreferences { error in
                if error != nil {
                    isError = true
                    Logger(.Error, "Failed to save preferences for network extension [\(error!)]")
                }
                semaphore.signal()
            }
        }
        if semaphore.wait(timeout: .distantFuture) == .timedOut || isError {
            return false
        }
        
        return true
    }
}
