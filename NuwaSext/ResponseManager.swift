//
//  ResponseManager.swift
//  NuwaSext
//
//  Created by ConradSun on 2022/8/19.
//

import Foundation

class ResponseManager {
    static let shared = ResponseManager()
    var replyQueue = DispatchQueue(label: "com.nuwastone.sext.replyqueue", attributes: .concurrent)
    var underwayEvent = Set<UInt64>()
    
    func addESAuthEvent(eventID: UInt64) {
        underwayEvent.update(with: eventID)
        let waitTime = DispatchTime.now() + .milliseconds(MaxWaitTime)
        replyQueue.asyncAfter(deadline: waitTime) {
            if self.underwayEvent.contains(eventID) {
                XPCServer.shared.replyAuthEvent(pointer: UInt(eventID), isAllowed: true)
            }
        }
    }
}
