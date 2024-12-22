//
//  ResponseManager.swift
//  NuwaSext
//
//  Created by ConradSun on 2022/8/19.
//

import Foundation
import EndpointSecurity

/// Auth event response manager
class ResponseManager {
    static let shared = ResponseManager()
    let replyQueue = DispatchQueue(label: "com.nuwastone.sext.replyqueue", attributes: .concurrent)
    let dictQueue = DispatchQueue(label: "com.nuwastone.sext.dictqueue", attributes: .concurrent)
    var underwayEvent = [UInt64: UnsafePointer<es_message_t>]()
    
    /// Called to reply auth event
    /// - Parameters:
    ///   - index: Event index to be replied
    ///   - isAllowed: Whether or not to be allowed execution
    func replyAuthEvent(index: UInt64, isAllowed: Bool) {
        let message = dictQueue.sync {
            underwayEvent[index]
        }
        guard message != nil else {
            Logger(.Debug, "Event [index: \(index)] has been replied.")
            return
        }
        
        dictQueue.async(flags: .barrier) {
            self.underwayEvent[index] = nil
        }
        
        let decision = isAllowed ? ES_AUTH_RESULT_ALLOW : ES_AUTH_RESULT_DENY
        if !ClientManager.shared.replyAuthEvent(message: message!, result: decision) {
            Logger(.Error, "Failed to reply auth event [index: \(index)].")
        }
    }
    
    /// Called to add auth event to reply queue
    /// - Parameters:
    ///   - index: Event index (unique)
    ///   - message: Event message
    func addAuthEvent(index: UInt64, message: UnsafePointer<es_message_t>) {
        dictQueue.async(flags: .barrier) {
            self.underwayEvent[index] = message
        }
                
        let waitTime = DispatchTime.now() + .milliseconds(MaxAuthWaitTime)
        replyQueue.asyncAfter(deadline: waitTime) {
            self.replyAuthEvent(index: index, isAllowed: true)
        }
    }
    
    /// Called to reply all events in queue
    func replyAllEvents() {
        dictQueue.sync {
            for item in underwayEvent {
                if !ClientManager.shared.replyAuthEvent(message: item.value, result: ES_AUTH_RESULT_ALLOW) {}
                Logger(.Error, "Failed to reply auth event [index: \(item.key)].")
            }
        }
        dictQueue.async(flags: .barrier) {
            self.underwayEvent.removeAll()
        }
    }
}
