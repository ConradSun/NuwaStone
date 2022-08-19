//
//  AppDelegate.swift
//  NuwaClient
//
//  Created by ConradSun on 2022/7/9.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet weak var startMenuItem: NSMenuItem!
    @IBOutlet weak var stopMenuItem: NSMenuItem!
    @IBOutlet weak var clearMenuItem: NSMenuItem!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setMenuStatus(start: true, stop: false)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if flag {
            return true
        }
        
        for window: AnyObject in sender.windows {
            if window.frameAutosaveName == "NuwaStoneMainWindow" {
                window.makeKeyAndOrderFront(self)
                return true
            }
        }
        return true
    }
    
    func setMenuStatus(start: Bool, stop: Bool) {
        startMenuItem.isEnabled = start
        stopMenuItem.isEnabled = stop
    }
}
