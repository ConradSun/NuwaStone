//
//  EventParser.swift
//  NuwaSext
//
//  Created by ConradSun on 2022/8/11.
//

import Foundation
import EndpointSecurity

extension ClientManager {
    func getString(token: es_string_token_t) -> String {
        if token.length > 0 {
            return String(cString: token.data)
        }
        return ""
    }
    
    func parseProcessProps(exec: es_event_exec_t, event: inout NuwaEventInfo) {
        var ref = exec
        var argv = [String]()
        let argc = es_exec_arg_count(&ref)
        
        for i in 0 ..< argc {
            argv.append(getString(token: es_exec_arg(&ref, i)))
        }
        
        event.procArgs = argv
        event.procCWD = getString(token: exec.cwd.pointee.path)
    }
    
    func parseExecEvent(message: UnsafePointer<es_message_t>, event: inout NuwaEventInfo, isAuth: Bool) {
        let process = message.pointee.event.exec.target.pointee
        
        event.pid = audit_token_to_pid(process.audit_token)
        event.ppid = process.ppid
        event.procPath = getString(token: process.executable.pointee.path)
        event.getNameFromUid(audit_token_to_euid(process.audit_token))
        event.props.updateValue(getString(token: process.signing_id), forKey: SigningID)
        parseProcessProps(exec: message.pointee.event.exec, event: &event)
        
        if isAuth {
            let result = es_respond_auth_result(esClient!, message, ES_AUTH_RESULT_ALLOW, false)
            if result != ES_RESPOND_RESULT_SUCCESS {
                Logger(.Warning, "Failed to respond auth event [\(result)].")
            }
        }
    }
}
