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
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
