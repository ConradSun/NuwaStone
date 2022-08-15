//
//  ClientManager.swift
//  NuwaSext
//
//  Created by ConradSun on 2022/8/11.
//

import Foundation
import EndpointSecurity

class ClientManager {
    var esClient: OpaquePointer?
    var initError = ESClientError.newClientError
    let subTypes = [ES_EVENT_TYPE_AUTH_EXEC,
                              ES_EVENT_TYPE_NOTIFY_EXEC,
                              ES_EVENT_TYPE_NOTIFY_EXIT,
                              ES_EVENT_TYPE_NOTIFY_CREATE,
                              ES_EVENT_TYPE_NOTIFY_UNLINK,
                              ES_EVENT_TYPE_NOTIFY_RENAME,
                              ES_EVENT_TYPE_NOTIFY_CLOSE]
    
    func startMonitoring() {
        var client: OpaquePointer?
        let eventQueue = DispatchQueue(label: "com.nuwastone.sext.eventqueue")
        
        eventQueue.sync {
            let result = es_new_client(&client) { _, message in
                self.dispatchMessage(message)
            }
            if result != ES_NEW_CLIENT_RESULT_SUCCESS {
                if result == ES_NEW_CLIENT_RESULT_ERR_NOT_ENTITLED {
                    Logger(.Error, "Failed to find Endpoint Security entitlement.")
                    initError = .missingEntitlements
                }
                
                Logger(.Error, "Failed to create ES client [\(result)].")
                return
            }
            if es_subscribe(client!, subTypes, UInt32(subTypes.count)) != ES_RETURN_SUCCESS {
                initError = .failedSubscription
                Logger(.Error, "Failed to subscribe event source.")
                return
            }
            
            esClient = client
            initError = .success
        }
    }
    
    func stopMonitoring() {
        if initError != .success || esClient == nil {
            return
        }
        
        if es_unsubscribe(esClient!, subTypes, UInt32(subTypes.count)) == ES_RETURN_ERROR {
            Logger(.Error, "Failed to unsubscibe event source.")
        }
        if es_delete_client(esClient) == ES_RETURN_ERROR {
            Logger(.Error, "Failed to delete ES client.")
        }
        esClient = nil
    }
    
    func dispatchMessage(_ message: UnsafePointer<es_message_t>) {
        let process = message.pointee.process.pointee
        var nuwaEvent = NuwaEventInfo()
        
        nuwaEvent.pid = audit_token_to_pid(process.audit_token)
        nuwaEvent.ppid = process.ppid
        nuwaEvent.procPath = getString(token: process.executable.pointee.path)
        nuwaEvent.getNameFromUid(audit_token_to_euid(process.audit_token))
        nuwaEvent.eventTime = UInt64(message.pointee.time.tv_sec)
        nuwaEvent.props.updateValue(getString(token: process.signing_id), forKey: "SigningID")
        
        switch message.pointee.event_type {
        case ES_EVENT_TYPE_AUTH_EXEC:
            nuwaEvent.eventType = .ProcessCreate
            parseExecEvent(message: message, event: &nuwaEvent, isAuth: true)
        case ES_EVENT_TYPE_NOTIFY_EXEC:
            nuwaEvent.eventType = .ProcessCreate
            parseExecEvent(message: message, event: &nuwaEvent, isAuth: false)
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
        
        if message.pointee.action_type == ES_ACTION_TYPE_AUTH {
            XPCServer.sharedInstance.sendAuthEvent(nuwaEvent)
        }
        else if message.pointee.action_type == ES_ACTION_TYPE_NOTIFY {
            XPCServer.sharedInstance.sendNotifyEvent(nuwaEvent)
        }
    }
}
