//
//  ResponseManager.swift
//  NuwaSext
//
//  Created by ConradSun on 2022/8/19.
//

import Foundation
import EndpointSecurity

class ResponseManager {
    static let shared = ResponseManager()
    let replyQueue = DispatchQueue(label: "com.nuwastone.sext.replyqueue", attributes: .concurrent)
    let replyLock = NSLock()
    var underwayEvent = Set<UInt64>()
    
    func replyAuthEvent(pointer: UInt, isAllowed: Bool) {
        replyLock.lock()
        guard underwayEvent.contains(UInt64(pointer)) else {
            replyLock.unlock()
            return
        }
        underwayEvent.remove(UInt64(pointer))
        replyLock.unlock()
        
        let message = UnsafePointer<es_message_t>.init(bitPattern: pointer)
        let decision = isAllowed ? ES_AUTH_RESULT_ALLOW : ES_AUTH_RESULT_DENY
        let result = es_respond_auth_result(ClientManager.shared.esClient!, message!, decision, false)
        
        if result != ES_RESPOND_RESULT_SUCCESS {
            if result == ES_RESPOND_RESULT_NOT_FOUND {
                Logger(.Warning, "Failed to respond auth event for not found.")
            }
            else {
                Logger(.Warning, "Failed to respond auth event [\(result)].")
            }
        }
        else {
            Logger(.Debug, "Reply event [\(pointer)] successfully.")
        }
    }
    
    func addAuthEvent(eventID: UInt64) {
        replyLock.lock()
        underwayEvent.update(with: eventID)
        replyLock.unlock()
        
        let waitTime = DispatchTime.now() + .milliseconds(MaxWaitTime)
        replyQueue.asyncAfter(deadline: waitTime) {
            self.replyAuthEvent(pointer: UInt(eventID), isAllowed: true)
        }
    }
}
