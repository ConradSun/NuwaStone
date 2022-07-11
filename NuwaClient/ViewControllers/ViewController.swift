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
        
        kextManager.loadKernelExtension()
        sleep(3)
        kextManager.unloadKernelExtension()
        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

