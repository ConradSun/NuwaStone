//
//  AppDelegate.swift
//  NuwaClient
//
//  Created by 孙康 on 2022/7/9.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var kextManager = KextManager()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if !kextManager.loadKernelExtension() {
            Logger(.Error, "Failed to load kext.")
            return
        }
        if !kextManager.setLogLevel(level: NuwaLogLevel.Info.rawValue) {
            Logger(.Error, "Failed to set log level.")
        }
        
        kextManager.listenRequestsForType(type: kQueueTypeAuth.rawValue)
        kextManager.listenRequestsForType(type: kQueueTypeNotify.rawValue)
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        if !kextManager.unloadKernelExtension() {
            Logger(.Error, "Failed to unload kext.")
        }
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

