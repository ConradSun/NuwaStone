//
//  main.swift
//  NuwaSext
//
//  Created by ConradSun on 2022/8/11.
//

import Foundation

autoreleasepool {
    XPCServer.shared.startListener()
    ClientManager.shared.startMonitoring()
    if ClientManager.shared.initError != .Success {
        exit(EXIT_FAILURE)
    }
}

dispatchMain()
