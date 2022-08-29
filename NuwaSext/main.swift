//
//  main.swift
//  NuwaSext
//
//  Created by ConradSun on 2022/8/11.
//

import Foundation
import NetworkExtension

autoreleasepool {
    NEProvider.startSystemExtensionMode()
    
    ClientManager.shared.startMonitoring()
    if ClientManager.shared.initError != .Success {
        exit(EXIT_FAILURE)
    }
    XPCServer.shared.startListener()
}

dispatchMain()
