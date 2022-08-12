//
//  XPCConnection.swift
//  NuwaSext
//
//  Created by ConradSun on 2022/8/11.
//

import Foundation

class XPCServer: NSObject {
    static let sharedInstance = XPCServer()
    var listener: NSXPCListener?
    var connection: NSXPCConnection?
}
