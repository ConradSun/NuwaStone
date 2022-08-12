//
//  main.swift
//  NuwaDaemon
//
//  Created by ConradSun on 2022/7/27.
//

import Foundation

var result = true
if #available(macOS 10.16, *) {
    
}
else {
    result = KextControl.loadExtension()
}

if result {
    XPCConnection.sharedInstance.startListener()
    RunLoop.current.run()
}
