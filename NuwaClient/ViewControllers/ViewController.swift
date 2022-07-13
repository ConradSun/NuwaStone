//
//  ViewController.swift
//  NuwaClient
//
//  Created by 孙康 on 2022/7/9.
//

import Cocoa

class ViewController: NSViewController {
    var kextManager = KextManager()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if !kextManager.loadKernelExtension() {
            Log(level: NuwaLogLevel.LOG_ERROR, "Failed to load kext.")
            return
        }
        if !kextManager.setLogLevel(level: NuwaLogLevel.LOG_INFO.rawValue) {
            Log(level: NuwaLogLevel.LOG_ERROR, "Failed to set log level.")
        }
        kextManager.listenRequestsForType(type: kQueueTypeAuth.rawValue)
        sleep(10)
        
        if !kextManager.unloadKernelExtension() {
            Log(level: NuwaLogLevel.LOG_ERROR, "Failed to unload kext.")
        }
        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
}

