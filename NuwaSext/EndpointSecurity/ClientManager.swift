//
//  ClientManager.swift
//  NuwaSext
//
//  Created by ConradSun on 2022/8/11.
//

import Foundation
import EndpointSecurity

class ClientManager {
    static let shared = ClientManager()
    var authCount = UInt64(0)
    var esClient: OpaquePointer?
    var initError = ESClientError.NewClientError
    let authQueue = DispatchQueue(label: "com.nuwastone.sext.authqueue", attributes: .concurrent)
    let notifyQueue = DispatchQueue(label: "com.nuwastone.sext.notifyqueue")
    let subTypes = [
        ES_EVENT_TYPE_AUTH_EXEC,
        ES_EVENT_TYPE_NOTIFY_EXEC,
        ES_EVENT_TYPE_NOTIFY_EXIT,
        ES_EVENT_TYPE_NOTIFY_CREATE,
        ES_EVENT_TYPE_NOTIFY_UNLINK,
        ES_EVENT_TYPE_NOTIFY_RENAME,
        ES_EVENT_TYPE_NOTIFY_CLOSE
    ]
    
    func startMonitoring() {
        var client: OpaquePointer?
        let eventQueue = DispatchQueue(label: "com.nuwastone.sext.eventqueue")
        let result = es_new_client(&client) { _, message in
            eventQueue.sync {
                self.processMessage(message)
            }
        }
        
        if result != ES_NEW_CLIENT_RESULT_SUCCESS {
            if result == ES_NEW_CLIENT_RESULT_ERR_NOT_ENTITLED {
                Logger(.Error, "Failed to find Endpoint Security entitlement.")
                initError = .MissingEntitlements
            }
            
            Logger(.Error, "Failed to create ES client [\(result)].")
            return
        }
        if es_subscribe(client!, subTypes, UInt32(subTypes.count)) != ES_RETURN_SUCCESS {
            es_delete_client(client)
            initError = .FailedSubscription
            Logger(.Error, "Failed to subscribe event source.")
            return
        }
        es_clear_cache(client!)
        
        esClient = client
        initError = .Success
        Logger(.Debug, "Create esclient successfully.")
    }
    
    func stopMonitoring() {
        if initError != .Success || esClient == nil {
            return
        }
        
        if es_unsubscribe(esClient!, subTypes, UInt32(subTypes.count)) == ES_RETURN_ERROR {
            Logger(.Error, "Failed to unsubscibe event source.")
        }
        if es_delete_client(esClient) == ES_RETURN_ERROR {
            Logger(.Error, "Failed to delete ES client.")
        }
        esClient = nil
        Logger(.Debug, "Delete esclient successfully.")
    }
    
    func processMessage(_ message: UnsafePointer<es_message_t>) {
        guard XPCServer.shared.connection != nil else {
            if message.pointee.action_type == ES_ACTION_TYPE_AUTH {
                replyAuthEvent(message: message, result: ES_AUTH_RESULT_ALLOW)
            }
            return
        }
        
        let process = message.pointee.process.pointee
        var nuwaEvent = NuwaEventInfo()
        
        nuwaEvent.pid = audit_token_to_pid(process.audit_token)
        nuwaEvent.ppid = process.ppid
        nuwaEvent.procPath = getString(token: process.executable.pointee.path)
        nuwaEvent.eventTime = UInt64(message.pointee.time.tv_sec)
        nuwaEvent.props[PropBundleID] = getString(token: process.signing_id)
        nuwaEvent.setUserName(uid: audit_token_to_euid(process.audit_token))
        
        switch message.pointee.event_type {
        case ES_EVENT_TYPE_AUTH_EXEC:
            nuwaEvent.eventType = .ProcessCreate
            parseExecEvent(message: message, event: &nuwaEvent)
        case ES_EVENT_TYPE_NOTIFY_EXEC:
            nuwaEvent.eventType = .ProcessCreate
            parseExecEvent(message: message, event: &nuwaEvent)
        case ES_EVENT_TYPE_NOTIFY_EXIT:
            nuwaEvent.eventType = .ProcessExit
            parseExitEvent(message: message, event: &nuwaEvent)
        case ES_EVENT_TYPE_NOTIFY_CREATE:
            nuwaEvent.eventType = .FileCreate
            parseCreateEvent(message: message, event: &nuwaEvent)
        case ES_EVENT_TYPE_NOTIFY_UNLINK:
            nuwaEvent.eventType = .FileDelete
            parseUnlinkEvent(message: message, event: &nuwaEvent)
        case ES_EVENT_TYPE_NOTIFY_RENAME:
            nuwaEvent.eventType = .FileRename
            parseRenameEvent(message: message, event: &nuwaEvent)
        case ES_EVENT_TYPE_NOTIFY_CLOSE:
            if !message.pointee.event.close.modified {
                return
            }
            nuwaEvent.eventType = .FileCloseModify
            parseCloseModifiedEvent(message: message, event: &nuwaEvent)
        default:
            return
        }
        
        dispatchEvent(event: nuwaEvent, message: message)
    }
    
    func dispatchEvent(event: NuwaEventInfo, message: UnsafePointer<es_message_t>) {
        if message.pointee.action_type == ES_ACTION_TYPE_AUTH {
            authQueue.async {
                guard let isWhite = ListManager.shared.containsAuthProcPath(vnodeID: event.eventID) else {
                    self.authCount += 1
                    event.eventID = self.authCount
                    XPCServer.shared.sendAuthEvent(event)
                    ResponseManager.shared.addAuthEvent(index: event.eventID, msgPtr: UInt64(UInt(bitPattern: message)))
                    return
                }
                let result = isWhite ? ES_AUTH_RESULT_ALLOW : ES_AUTH_RESULT_DENY
                self.replyAuthEvent(message: message, result: result)
                Logger(.Info, "Process [\(event.procPath)] is contained in auth list.")
            }
        }
        else if message.pointee.action_type == ES_ACTION_TYPE_NOTIFY {
            notifyQueue.sync {
                if event.eventType == .ProcessCreate || event.eventType == .ProcessExit {
                    XPCServer.shared.sendNotifyEvent(event)
                    return
                }
                if !ListManager.shared.containsFilterFilePath(vnodeID: event.eventID) {
                    XPCServer.shared.sendNotifyEvent(event)
                }
            }
        }
    }
    
    func replyAuthEvent(message: UnsafePointer<es_message_t>, result: es_auth_result_t) {
        let ret = es_respond_auth_result(self.esClient!, message, result, false)
        if ret != ES_RESPOND_RESULT_SUCCESS {
            Logger(.Error, "Failed to respond auth event [\(ret)].")
        }
    }
}
