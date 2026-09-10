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
        // Take and remove the message atomically so concurrent replies
        // (client decision vs. fallback) can never respond twice.
        let message = dictQueue.sync(flags: .barrier) {
            let message = underwayEvent[index]
            underwayEvent[index] = nil
            return message
        }
        guard message != nil else {
            Logger(.Debug, "Event [index: \(index)] has been replied.")
            return
        }

        respondAndRelease(message: message!, isAllowed: isAllowed)
    }

    /// Called to respond auth result for a retained message and release it
    private func respondAndRelease(message: UnsafePointer<es_message_t>, isAllowed: Bool) {
        let decision = isAllowed ? ES_AUTH_RESULT_ALLOW : ES_AUTH_RESULT_DENY
        if !ClientManager.shared.replyAuthEvent(message: message, result: decision) {
            Logger(.Error, "Failed to reply auth event [index: \(message.pointee.seq_num)].")
        }
        es_release_message(message)
    }

    /// Called to add auth event to reply queue
    /// - Parameters:
    ///   - index: Event index (unique)
    ///   - message: Event message
    func addAuthEvent(index: UInt64, message: UnsafePointer<es_message_t>) {
        // The message is only valid before the handler returns; retain it
        // so the deferred respond (and the fallback) operate on a valid message.
        es_retain_message(message)
        dictQueue.async(flags: .barrier) {
            self.underwayEvent[index] = message
        }

        let waitTime = DispatchTime.now() + .milliseconds(MaxAuthFallbackTime)
        replyQueue.asyncAfter(deadline: waitTime) {
            self.replyAuthEvent(index: index, isAllowed: true)
        }
    }

    /// Called to reply all events in queue
    func replyAllEvents() {
        dictQueue.sync(flags: .barrier) {
            for (index, message) in self.underwayEvent {
                let decision = ES_AUTH_RESULT_ALLOW
                if !ClientManager.shared.replyAuthEvent(message: message, result: decision) {
                    Logger(.Error, "Failed to reply auth event [index: \(index)].")
                }
                es_release_message(message)
            }
            self.underwayEvent.removeAll()
        }
    }
}
