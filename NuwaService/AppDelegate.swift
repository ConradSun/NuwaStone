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
        var result = true
        if #available(macOS 10.16, *) {
            let control = SextControl()
            control.activateExtension()
            while !control.isFinished {
                usleep(1000)
            }
            result = control.isConnected
        }
        else {
            let control = KextControl()
            result = control.loadExtension()
        }

        if result {
            XPCConnection.shared.startListener()
        }
        else {
            Logger(.Error, "Failed to load extension.")
            exit(EXIT_FAILURE)
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

