//
//  DNSResolver.swift
//  NuwaSext
//
//  Created by ConradSun on 2022/9/6.
//

import Foundation
import Network

fileprivate enum TypeCode: UInt {
    case A      = 1
    case CNAME  = 5
    case AAAA   = 28
}

fileprivate enum ClassCode: UInt {
    case IN     = 1
    case S      = 2
    case CH     = 3
    case HS     = 4
    case NONE   = 254
    case ANY    = 255
}

fileprivate struct MessageHeader {
    var transID: UInt16
    var flags: UInt16
    var questions: UInt16
    var answers: UInt16
    var authorities: UInt16
    var additionals: UInt16
    init() {
        transID = 0
        flags = 0
        questions = 0
        answers = 0
        authorities = 0
        additionals = 0
    }
}

fileprivate struct QueryInfo {
    var dnsType: UInt16
    var dnsClass: UInt16
}

fileprivate struct ResponseInfo {
    var dnsType: UInt16
    var dnsClass: UInt16
    var liveTime: UInt32
    var length: UInt16
    init() {
        dnsType = 0
        dnsClass = 0
        liveTime = 0
        length = 0
    }
}

struct DNSParseResult {
    var replyCode: UInt16
    var domainName: String
    var queryResult: String
    init() {
        replyCode = 0
        domainName = ""
        queryResult = ""
    }
}

class DNSResolver {
    private let headerSize = 12
    private let querySize = 4
    private let replySize = 10
    
    private var originData = Data()
    private var parseIndex = 0
    private var nameDict = [String: UInt16]()
    var results = [DNSParseResult]()
    
    private func ntohs(data: Data, index: Int) -> UInt16 {
        return (UInt16(data[index]) << 8) | UInt16(data[index+1])
    }
    
    private func parseDomainName(begin: Int, domainName: inout String) ->Bool {
        if begin >= originData.count {
            return false
        }
        
        let offsetSymbol:UInt8 = 0xc0
        let endSymbol:UInt8 = 0x00
        var currentSite = begin
        var occupyCount = 0
        
        if originData[currentSite] == offsetSymbol {
            occupyCount = 2
            currentSite = Int(originData[currentSite + 1])
            Logger(.Debug, "Domain address is offseted.")
        }
        while currentSite < originData.count && originData[currentSite] != endSymbol {
            if originData[currentSite] == offsetSymbol {
                domainName += "."
                occupyCount = occupyCount == 0 ? (currentSite - begin + 1) : occupyCount
                parseIndex += occupyCount
                return parseDomainName(begin: currentSite, domainName: &domainName)
            }
            
            let count = originData[currentSite]
            currentSite += 1
            if !domainName.isEmpty {
                domainName += "."
            }
            if count >= (originData.count-currentSite) {
                Logger(.Error, "Domain name is invalid.")
                return false
            }
            for _ in 0 ..< count {
                let char = Character(UnicodeScalar(originData[currentSite]))
                domainName.append(char)
                currentSite += 1
            }
        }
        
        occupyCount = occupyCount == 0 ? (currentSite - begin + 1) : occupyCount
        parseIndex += occupyCount
        return true
    }
    
    private func parseQuery(count: UInt16, rcode: UInt16) -> Bool {
        for i in 0 ..< count {
            var result = DNSParseResult()
            result.replyCode = rcode
            if !parseDomainName(begin: parseIndex, domainName: &result.domainName) {
                return false
            }
            parseIndex += querySize
            results.append(result)
            nameDict.updateValue(i, forKey: result.domainName)
        }
        return true
    }
    
    private func processIPAddr(addrFamily: Int32, addr: UnsafeRawPointer, domainName: String) {
        guard let index = nameDict[domainName] else {
            return
        }
        
        var tempString = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        inet_ntop(addrFamily, addr, &tempString, socklen_t(MAXPATHLEN))
        
        if !results[Int(index)].queryResult.isEmpty {
            results[Int(index)].queryResult += ","
        }
        results[Int(index)].queryResult += String(cString: &tempString)
    }
    
    private func processCanonicalName(begin: Int, domainName: String) {
        guard let index = nameDict[domainName] else {
            return
        }
        
        var name = ""
        if !parseDomainName(begin: begin, domainName: &name) {
            return
        }
        nameDict.updateValue(index, forKey: name)
    }
    
    private func parseReplyItem() -> Bool {
        var result = DNSParseResult()
        if !parseDomainName(begin: parseIndex, domainName: &result.domainName) {
            return false
        }
        if originData.count - parseIndex <= replySize {
            return false
        }
        
        var info = ResponseInfo()
        info.dnsType = ntohs(data: originData, index: parseIndex)
        info.length = ntohs(data: originData, index: parseIndex+8)
        
        let type = TypeCode(rawValue: UInt(info.dnsType))
        originData.withUnsafeBytes { pointer in
            
            guard var addr = pointer.baseAddress else {
                return
            }
            addr += parseIndex + replySize
            
            switch type {
            case .A:
                processIPAddr(addrFamily: AF_INET, addr: addr, domainName: result.domainName)
            case .CNAME:
                processCanonicalName(begin: parseIndex + replySize, domainName: result.domainName)
                parseIndex -= Int(info.length)
            case .AAAA:
                processIPAddr(addrFamily: AF_INET6, addr: addr, domainName: result.domainName)
            default:
                break
            }
        }
        parseIndex += Int(info.length)
        return true
    }
    
    private func parseReply(count: UInt16) -> Bool {
        for _ in 0 ..< count {
            if !parseReplyItem() {
                return false
            }
            parseIndex += replySize
        }
        return true
    }
    
    func parseMessage(message: Data, proto: Int32) {
        if proto == IPPROTO_UDP {
            if message.count <= headerSize {
                return
            }
            parseIndex = 0
        }
        else if proto == IPPROTO_TCP {
            if message.count <= headerSize + MemoryLayout<UInt16>.size {
                return
            }
            parseIndex = MemoryLayout<UInt16>.size
        }
        else {
            return
        }
        originData = message
        
        var header = MessageHeader()
        header.transID = ntohs(data: originData, index: parseIndex)
        header.flags = ntohs(data: originData, index: parseIndex+2)
        header.questions = ntohs(data: originData, index: parseIndex+4)
        header.answers = ntohs(data: originData, index: parseIndex+6)
        parseIndex += headerSize
        let replyCode = header.flags & 0x000f
        
        if !parseQuery(count: header.questions, rcode: replyCode) || !parseReply(count: header.answers) {
            Logger(.Warning, "Failed to parse dns packet.")
            results.removeAll()
            return
        }
    }
}
