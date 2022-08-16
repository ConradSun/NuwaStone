//
//  main.swift
//  NuwaSext
//
//  Created by ConradSun on 2022/8/11.
//

import Foundation

autoreleasepool {
    XPCServer.sharedInstance.startListener()
    ClientManager.sharedInstance.startMonitoring()
    if ClientManager.sharedInstance.initError != .success {
        exit(EXIT_FAILURE)
    }
}

dispatchMain()
