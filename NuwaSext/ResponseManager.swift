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
    var replyQueue = DispatchQueue(label: "com.nuwastone.sext.replyqueue", attributes: .concurrent)
    var underwayEvent = Set<UInt64>()
    
    func replyAuthEvent(pointer: UInt, isAllowed: Bool) {
        guard underwayEvent.contains(UInt64(pointer)) else {
            return
        }
        
        underwayEvent.remove(UInt64(pointer))
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
        underwayEvent.update(with: eventID)
        let waitTime = DispatchTime.now() + .milliseconds(MaxWaitTime)
        replyQueue.asyncAfter(deadline: waitTime) {
            if self.underwayEvent.contains(eventID) {
                Logger(.Warning, "Auto allow event [\(eventID)] for timeout.")
                self.replyAuthEvent(pointer: UInt(eventID), isAllowed: true)
            }
        }
    }
}
