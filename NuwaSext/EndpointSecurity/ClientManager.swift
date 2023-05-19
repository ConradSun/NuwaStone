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
    
    let typeDict = [
        ES_EVENT_TYPE_AUTH_EXEC.rawValue: "AuthExec",
        ES_EVENT_TYPE_NOTIFY_EXEC.rawValue: "NotifyExec",
        ES_EVENT_TYPE_NOTIFY_EXIT.rawValue: "NotifyExit",
        ES_EVENT_TYPE_NOTIFY_CREATE.rawValue: "NotifyCreate",
        ES_EVENT_TYPE_NOTIFY_UNLINK.rawValue: "NotifyUnlink",
        ES_EVENT_TYPE_NOTIFY_RENAME.rawValue: "NotifyRename",
        ES_EVENT_TYPE_NOTIFY_CLOSE.rawValue: "NotifyClose"
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
        es_clear_cache(client!)
        if es_subscribe(client!, subTypes, UInt32(subTypes.count)) != ES_RETURN_SUCCESS {
            es_delete_client(client)
            initError = .FailedSubscription
            Logger(.Error, "Failed to subscribe event source.")
            return
        }
        
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
        ResponseManager.shared.replyAllEvents()
        
        if es_delete_client(esClient) == ES_RETURN_ERROR {
            Logger(.Error, "Failed to delete ES client.")
        }
        esClient = nil
        Logger(.Debug, "Delete esclient successfully.")
    }
    
    func processMessage(_ message: UnsafePointer<es_message_t>) {
        guard XPCServer.shared.connection != nil else {
            if message.pointee.action_type == ES_ACTION_TYPE_AUTH {
                _ = replyAuthEvent(message: message, result: ES_AUTH_RESULT_ALLOW)
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
            if message.pointee.event.exec.target.pointee.is_es_client {
                _ = replyAuthEvent(message: message, result: ES_AUTH_RESULT_ALLOW)
            }
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
            authQueue.sync { [self] in
                guard let isWhite = ListManager.shared.shouldAllowProcExec(vnodeID: event.eventID) else {
                    if event.props[PropCodeSign] != nil {
                        if !replyAuthEvent(message: message, result: ES_AUTH_RESULT_ALLOW) {
                            Logger(.Error, "Failed to respond auth event [\(event.desc)].")
                        }
                        return
                    }
                    
                    authCount += 1
                    event.eventID = authCount
                    if !XPCServer.shared.sendAuthEvent(event) {
                        Logger(.Warning, "Failed to send auth event [index: \(event.eventID)].")
                        if !replyAuthEvent(message: message, result: ES_AUTH_RESULT_ALLOW) {
                            Logger(.Error, "Failed to reply auth event [\(event.desc)].")
                        }
                    }
                    else {
                        ResponseManager.shared.addAuthEvent(index: event.eventID, message: message)
                    }
                    return
                }
                
                let result = isWhite ? ES_AUTH_RESULT_ALLOW : ES_AUTH_RESULT_DENY
                if !replyAuthEvent(message: message, result: result) {
                    Logger(.Error, "Failed to respond auth event [\(event.desc)].")
                }
                Logger(.Info, "Process [\(event.procPath)] is contained in auth list.")
            }
        }
        else if message.pointee.action_type == ES_ACTION_TYPE_NOTIFY {
            notifyQueue.sync {
                if event.eventType == .ProcessCreate || event.eventType == .ProcessExit {
                    XPCServer.shared.sendNotifyEvent(event)
                    return
                }
                if !ListManager.shared.shouldAbandonFileEvent(fileVnodeID: event.eventID, procVnodeID: getFileVnodeID(event.procPath)) {
                    XPCServer.shared.sendNotifyEvent(event)
                }
            }
        }
    }
    
    func replyAuthEvent(message: UnsafePointer<es_message_t>, result: es_auth_result_t) ->Bool {
        if message.pointee.action_type != ES_ACTION_TYPE_AUTH {
            Logger(.Warning, "Event [type: \(typeDict[message.pointee.event_type.rawValue]!)] to be replied is not auth type.")
            return false
        }
        
        let ret = es_respond_auth_result(esClient!, message, result, false)
        if ret != ES_RESPOND_RESULT_SUCCESS {
            Logger(.Error, "Failed to respond auth event with error [\(ret.rawValue)].")
            return false
        }
        return true
    }
}
