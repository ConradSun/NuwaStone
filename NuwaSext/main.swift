//
//  main.swift
//  NuwaSext
//
//  Created by ConradSun on 2022/8/11.
//

import Foundation

let manager = ClientManager()
manager.startMonitoring()
if manager.initError != .success {
    exit(EXIT_FAILURE)
}

dispatchMain()
