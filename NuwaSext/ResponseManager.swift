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
    let dictQueue = DispatchQueue(label: "com.nuwastone.sext.dictqueue", attributes: .concurrent)
    var underwayEvent = [UInt64: UInt64]()
    
    func replyAuthEvent(index: UInt64, isAllowed: Bool) {
        let pointer = dictQueue.sync {
            underwayEvent[index]
        }
        guard pointer != nil else {
            Logger(.Debug, "Event [index: \(index)] has been replied.")
            return
        }
        
        dictQueue.async {
            self.underwayEvent[index] = nil
        }
        
        let message = UnsafePointer<es_message_t>.init(bitPattern: UInt(pointer!))
        let decision = isAllowed ? ES_AUTH_RESULT_ALLOW : ES_AUTH_RESULT_DENY
        let result = es_respond_auth_result(ClientManager.shared.esClient!, message!, decision, false)
        
        if result != ES_RESPOND_RESULT_SUCCESS {
            if result == ES_RESPOND_RESULT_NOT_FOUND {
                Logger(.Error, "Failed to respond auth event for not found.")
            }
            else {
                Logger(.Error, "Failed to respond auth event [\(result)].")
                
            }
        }
    }
    
    func addAuthEvent(index: UInt64, msgPtr: UInt64) {
        dictQueue.async {
            self.underwayEvent[index] = msgPtr
        }
                
        let waitTime = DispatchTime.now() + .milliseconds(MaxWaitTime)
        replyQueue.asyncAfter(deadline: waitTime) {
            self.replyAuthEvent(index: index, isAllowed: true)
        }
    }
}
