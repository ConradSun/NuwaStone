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
    
    func getVnodeID(fileStat: stat) -> UInt64 {
        let dev = UInt64(truncating: fileStat.st_dev as NSNumber)
        let ino = UInt64(truncating: fileStat.st_ino as NSNumber)
        let vnodeID = (dev << 32) | ino
        return vnodeID
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
    
    func parseExecEvent(message: UnsafePointer<es_message_t>, event: inout NuwaEventInfo) {
        let process = message.pointee.event.exec.target.pointee
        
        event.eventID = getVnodeID(fileStat: process.executable.pointee.stat)
        event.pid = audit_token_to_pid(process.audit_token)
        event.ppid = process.ppid
        event.procPath = getString(token: process.executable.pointee.path)
        event.props[PropBundleID] = getString(token: process.signing_id)
        event.setUserName(uid: audit_token_to_euid(process.audit_token))
        event.fillCodeSign()
        parseProcessProps(exec: message.pointee.event.exec, event: &event)
    }
    
    func parseExitEvent(message: UnsafePointer<es_message_t>, event: inout NuwaEventInfo) {
        event.props[PropExitCode] = String(message.pointee.event.exit.stat)
    }
    
    func parseOpenEvent(message: UnsafePointer<es_message_t>, event: inout NuwaEventInfo) {
        event.eventID = getVnodeID(fileStat: message.pointee.event.open.file.pointee.stat)
        event.props[PropFilePath] = getString(token: message.pointee.event.open.file.pointee.path)
    }
    
    func parseCreateEvent(message: UnsafePointer<es_message_t>, event: inout NuwaEventInfo) {
        event.eventID = getVnodeID(fileStat: message.pointee.event.create.destination.existing_file.pointee.stat)
        event.props[PropFilePath] = getString(token: message.pointee.event.create.destination.existing_file.pointee.path)
    }
    
    func parseUnlinkEvent(message: UnsafePointer<es_message_t>, event: inout NuwaEventInfo) {
        event.eventID = getVnodeID(fileStat: message.pointee.event.unlink.target.pointee.stat)
        event.props[PropFilePath] = getString(token: message.pointee.event.unlink.target.pointee.path)
    }
    
    func parseRenameEvent(message: UnsafePointer<es_message_t>, event: inout NuwaEventInfo) {
        var dstPath = ""
        if message.pointee.event.rename.destination_type == ES_DESTINATION_TYPE_EXISTING_FILE {
            dstPath = getString(token: message.pointee.event.rename.destination.existing_file.pointee.path)
        } else {
            dstPath = getString(token: message.pointee.event.rename.destination.new_path.dir.pointee.path)
            dstPath = dstPath + "/" + getString(token: message.pointee.event.rename.destination.new_path.filename)
        }
        event.eventID = getVnodeID(fileStat: message.pointee.event.rename.source.pointee.stat)
        event.props[PropSrcPath] = getString(token: message.pointee.event.rename.source.pointee.path)
        event.props[PropDstPath] = dstPath
    }
    
    func parseCloseModifiedEvent(message: UnsafePointer<es_message_t>, event: inout NuwaEventInfo) {
        event.eventID = getVnodeID(fileStat: message.pointee.event.close.target.pointee.stat)
        event.props[PropFilePath] = getString(token: message.pointee.event.close.target.pointee.path)
    }
}
