//
//  AppDelegate.swift
//  NuwaService
//
//  Created by ConradSun on 2022/8/12.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        XPCConnection.shared.startListener()
        
        if #available(macOS 11.0, *) {
            SextControl.shared.activateExtension()
        } else {
            if !KextControl.shared.loadExtension() {
                Logger(.Error, "Failed to load kernel extension.")
                exit(EXIT_FAILURE)
            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

