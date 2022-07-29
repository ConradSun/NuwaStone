//
//  main.swift
//  NuwaDaemon
//
//  Created by ConradSun on 2022/7/27.
//

import Foundation

XPCConnection.sharedInstance.startListener()
RunLoop.current.run()
