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
    
    let menuBar = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setMenuStatus(start: true, stop: false)
        setupMenuBar()
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
        
        if let window = getMainWindow(sender) {
            window.makeKeyAndOrderFront(self)
        }
        return true
    }
}

extension AppDelegate {
    @objc func hideDockIcon() {
        NSApp.setActivationPolicy(.accessory)
        getMainWindow(NSApplication.shared)?.close()
    }
    
    @objc func showDockIcon() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        getMainWindow(NSApplication.shared)?.makeKeyAndOrderFront(self)
    }
    
    func getMainWindow(_ sender: NSApplication) -> NSWindow? {
        for window: AnyObject in sender.windows {
            if window.frameAutosaveName == "NuwaStoneMainWindow" {
                return window as? NSWindow
            }
        }
        return nil
    }
    
    func setMenuStatus(start: Bool, stop: Bool) {
        startMenuItem.isEnabled = start
        stopMenuItem.isEnabled = stop
    }
    
    func setupMenuBar() {
        let statusMenu = NSMenu()
        statusMenu.addItem(withTitle: "Run in Background", action: #selector(hideDockIcon), keyEquivalent: "")
        statusMenu.addItem(withTitle: "Show App Window", action: #selector(showDockIcon), keyEquivalent: "")
        statusMenu.addItem(withTitle: "Quit NuwaStone", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        
        menuBar.button!.image = NSImage(named: NSImage.Name("MenuIcon"))
        menuBar.button!.toolTip = "NuwaStone"
        menuBar.menu = statusMenu
    }
}
