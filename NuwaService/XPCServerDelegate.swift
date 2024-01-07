//
//  XPCServerDelegate.swift
//  NuwaService
//
//  Created by ConradSun on 2023/5/16.
//

import AppKit
import Foundation

extension XPCConnection: NSXPCListenerDelegate {
    func startListener() {
        let newListener = NSXPCListener(machServiceName: DaemonBundle)
        newListener.delegate = self
        newListener.resume()
        listener = newListener
        Logger(.Info, "Start XPC listener successfully.")
    }
    
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        guard connection == nil else {
            Logger(.Warning, "Client connected already.")
            return false
        }
        
        if !verifyXPCPeer(pid: newConnection.processIdentifier) {
            Logger(.Error, "Failed to verify the peer.")
            return false
        }
        
        newConnection.exportedObject = self
        newConnection.exportedInterface = NSXPCInterface(with: DaemonXPCProtocol.self)
        newConnection.remoteObjectInterface = NSXPCInterface(with: ClientXPCProtocol.self)
        newConnection.invalidationHandler = {
            self.connection = nil
            Logger(.Info, "Client disconnected.")
        }
        newConnection.interruptionHandler = {
            self.connection = nil
            Logger(.Info, "Client interrupted.")
        }
        
        Logger(.Info, "Client connected successfully.")
        connection = newConnection
        newConnection.resume()
        return true
    }
    
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
    
    private func getMachServiceName(from bundle: Bundle) -> String {
        let clientKeys = bundle.object(forInfoDictionaryKey: ClientName) as? [String: Any]
        let machServiceName = clientKeys?[MachServiceKey] as? String
        return machServiceName ?? ""
    }
}

extension XPCConnection: DaemonXPCProtocol {
    func connectResponse(_ handler: @escaping (Bool) -> Void) {
        Logger(.Info, "Client connected.")
        enableExtensionStart()
        handler(true)
    }
    
    func getProcessPath(pid: Int32, eventHandler: @escaping (String, Int32) -> Void) {
        getProcPath(pid: pid, eventHandler: eventHandler)
    }
    
    func getProcessCurrentDir(pid: Int32, eventHandler: @escaping (String, Int32) -> Void) {
        getProcCurrentDir(pid: pid, eventHandler: eventHandler)
    }
    
    func getProcessArgs(pid: Int32, eventHandler: @escaping ([String], Int32) -> Void) {
        getProcArgs(pid: pid, eventHandler: eventHandler)
    }
    
    func launchUninstaller() {
        Logger(.Info, "Begin to uninstall NuwaStone.")
        
        if #available(macOS 11.0, *) {
            SextControl.shared.deactivateExtension()
        } else {
            _ = KextControl.shared.unloadExtension()
        }
        
        let url = URL(fileURLWithPath: "Contents/Resources/uninstall.sh", relativeTo: Bundle.main.bundleURL)
        let task = Process()
        task.arguments = ["-c", url.path]
        
        if #available(macOS 10.13, *) {
            task.executableURL = URL(fileURLWithPath: "/bin/zsh")
            do {
                try task.run()
            } catch {}
        } else {
            task.launchPath = "/bin/zsh"
            task.launch()
        }
    }
    
    func enableExtensionStart() {
        if #available(macOS 11.0, *) {
            if !SextControl.shared.getExtensionStatus() {
                SextControl.shared.activateExtension()
            }
            _ = SextControl.shared.switchNEStatus(true)
        } else {
            if !KextControl.shared.getExtensionStatus() {
                _ = KextControl.shared.loadExtension()
            }
        }
    }
}
