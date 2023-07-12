//
//  XPCServerDelegate.swift
//  NuwaService
//
//  Created by ConradSun on 2023/5/16.
//

import Foundation

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
        } else {
            if !KextControl.shared.getExtensionStatus() {
                _ = KextControl.shared.loadExtension()
            }
        }
    }
}
