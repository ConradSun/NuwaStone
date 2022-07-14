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
            Log(level: NuwaLogLevel.LOG_ERROR, "Failed to load kext.")
            return
        }
        if !kextManager.setLogLevel(level: NuwaLogLevel.LOG_INFO.rawValue) {
            Log(level: NuwaLogLevel.LOG_ERROR, "Failed to set log level.")
        }
        
        kextManager.listenRequestsForType(type: kQueueTypeAuth.rawValue)
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        if !kextManager.unloadKernelExtension() {
            Log(level: NuwaLogLevel.LOG_ERROR, "Failed to unload kext.")
        }
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

