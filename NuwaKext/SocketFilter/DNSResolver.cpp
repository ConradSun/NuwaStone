//
//  DNSResolver.cpp
//  NuwaKext
//
//  Created by ConradSun on 2022/8/30.
//

#include "DNSResolver.hpp"
#include "KextLogger.hpp"

#pragma mark - DNS Resolver

DNSResolver::DNSResolver(const char *packet, size_t size, UInt8 proto) {
    m_originPacket = packet;
    m_packetSize = size;
    m_protocol = proto;
    m_parseResults = {0, nullptr};
    bzero(&m_domainMap, sizeof(m_domainMap));
}

DNSResolver::~DNSResolver() {
    if (m_parseResults.results != nullptr) {
        IOFreeAligned(m_parseResults.results, sizeof(DNSParseResult)*m_parseResults.count);
        m_parseResults.results = nullptr;
    }
    
    for (UInt8 i = 0; i < kMaxNameCount; ++i) {
        if (m_domainMap[i].domainName == nullptr) {
            break;
        }
        size_t size = strlen(m_domainMap[i].domainName) + 1;
        IOFreeAligned(m_domainMap[i].domainName, size);
        m_domainMap[i].domainName = nullptr;
    }
}

bool DNSResolver::setDoaminMap(const char *domainName, UInt16 index) {
    DNSDomainMap *map = nullptr;
    for (UInt8 i = 0; i < kMaxNameCount; ++i) {
        if (m_domainMap[i].domainName == nullptr) {
            map = &m_domainMap[i];
            break;
        }
    }
    if (map == nullptr) {
        return false;
    }
    
    size_t size = strlen(domainName) + 1;
    map->domainName = (char *)IOMallocAligned(size, 2);
    if (map->domainName == nullptr) {
        return false;
    }
    
    strlcpy(map->domainName, domainName, size);
    map->index = index;
    return true;
}

SInt16 DNSResolver::getDomainIndex(const char *domainName) {
    for (UInt8 i = 0; i < kMaxNameCount; ++i) {
        if (m_domainMap[i].domainName == nullptr) {
            return -1;
        }
        if (strcmp(domainName, m_domainMap[i].domainName) == 0) {
            return m_domainMap[i].index;
        }
    }
    return -1;
}

bool DNSResolver::parseDomainName(const char *nameBegin, char *domainName, UInt16 nameSize) {
    if (nameBegin == nullptr || domainName == nullptr || nameSize == 0) {
        return false;
    }
    
    static char offsetSymbol = 0xc0;
    static char endSymbol = 0x00;
    const char *parseBegin = nameBegin;
    const char *parseEnd = m_originPacket + m_packetSize;
    
    UInt16 nameLen = 0;
    UInt16 occupyCount = 0;
    
    if (*parseBegin == offsetSymbol) {
        occupyCount = 2;
        parseBegin = m_originPacket + *(parseBegin + 1);
        Logger(LOG_DEBUG, "Domain address is offseted.")
    }
    
    while (parseBegin < parseEnd && *parseBegin != endSymbol) {
        if (*parseBegin == offsetSymbol) {
            domainName[nameLen++] = '.';
            occupyCount = occupyCount == 0 ? (parseBegin - nameBegin + 1) : occupyCount;
            m_parseIndex += occupyCount;
            return parseDomainName(parseBegin, domainName+nameLen, nameSize-nameLen);
        }
        
        UInt8 count = *parseBegin++;
        if (nameLen != 0) {
            domainName[nameLen++] = '.';
        }
        if (count >= (nameSize-nameLen)) {
            Logger(LOG_ERROR, "Domain name is too long.")
            return false;
        }
        if (count >= (parseEnd-parseBegin)) {
            Logger(LOG_ERROR, "Domain name is invalid.")
            return false;
        }
        for (UInt8 i = 0; i < count; ++i) {
            domainName[nameLen++] = *parseBegin++;
        }
    }
    domainName[nameLen] = '\0';
    
    occupyCount = occupyCount == 0 ? (parseBegin - nameBegin + 1) : occupyCount;
    m_parseIndex += occupyCount;
    return true;
}

bool DNSResolver::parseQuery(UInt16 queryCount, UInt16 replyCode) {
    for (UInt16 i = 0; i < queryCount; ++i) {
        m_parseResults.results[i].replyCode = replyCode;
        if (!parseDomainName(m_originPacket+m_parseIndex, m_parseResults.results[i].domainName, kMaxNameLength)) {
            return false;
        }
        
        m_parseIndex += kDNSQuerySize;
        if (m_parseIndex >= m_packetSize) {
            return false;
        }
        if (!setDoaminMap(m_parseResults.results[i].domainName, i)) {
            return false;
        }
    }
    
    return true;
}

bool DNSResolver::processReplyResult(const char *domain, const char *result, UInt16 type) {
    SInt16 index = getDomainIndex(domain);
    if (index < 0) {
        Logger(LOG_ERROR, "Unknown reply domain name [%s].", result)
        return false;
    }
    
    if (type == kDNSType_CNAME) {
        return setDoaminMap(result, index);
    }
    else {
        size_t length = strlen(m_parseResults.results[index].queryResult);
        if (length + strlen(result) + 1 >= kMaxPathLength) {
            Logger(LOG_ERROR, "Reply info is too much.")
            return false;
        }
        if (length > 0) {
            m_parseResults.results[index].queryResult[length++] = ',';
        }
        strlcpy(m_parseResults.results[index].queryResult+length, result, kMaxPathLength-length);
    }
    
    return true;
}

bool DNSResolver::parseReplyItem(DNSParseResult *result) {
    if (!parseDomainName(m_originPacket+m_parseIndex, result->domainName, kMaxNameLength)) {
        return false;
    }
    
    DNSResponseInfo info = *(DNSResponseInfo *)(m_originPacket + m_parseIndex);
    info.DNSType = ntohs(info.DNSType);
    info.DNSClass = ntohs(info.DNSClass);
    info.liveTime = ntohl(info.liveTime);
    info.length = ntohs(info.length);
    result->replyType = info.DNSType;
    
    const char *messageBegin = m_originPacket + m_parseIndex + kDNSReplySize;
    m_parseIndex += info.length;
    switch (result->replyType) {
        case kDNSType_A:
            inet_ntop(AF_INET, messageBegin, result->queryResult, kMaxPathLength);
            Logger(LOG_DEBUG, "The replied result is IPv4 [%s].", result->queryResult)
            break;
        case kDNSType_CNAME:
            parseDomainName(messageBegin, result->queryResult, kMaxPathLength);
            m_parseIndex -= info.length;
            Logger(LOG_DEBUG, "The replied result is canonical name [%s].", result->queryResult)
            break;
        case kDNSType_AAAA:
            inet_ntop(AF_INET6, messageBegin, result->queryResult, kMaxPathLength);
            Logger(LOG_DEBUG, "The replied result is IPv6 [%s].", result->queryResult)
            break;
        default:
            return true;
    }
    
    return processReplyResult(result->domainName, result->queryResult, result->replyType);
}

bool DNSResolver::parseReply(UInt16 replyCount) {
    DNSParseResult tempResult = {};
    for (UInt16 i = 0; i < replyCount; ++i) {
        bzero(&tempResult, sizeof(DNSParseResult));
        if (!parseReplyItem(&tempResult)) {
            return false;
        }
        
        m_parseIndex += kDNSReplySize;
        if (m_parseIndex > m_packetSize) {
            return false;
        }
    }
    
    return true;
}

void DNSResolver::parsePacket() {
    DNSMessageHeader header = *(DNSMessageHeader *)m_originPacket;
    header.transID = ntohs(header.transID);
    header.flags = ntohs(header.flags);
    header.questions = ntohs(header.questions);
    header.answers = ntohs(header.answers);
    
    UInt16 replyCode = header.flags & 0x000f;
    size_t allocSize = sizeof(DNSParseResult) * header.questions;
    m_parseResults.results = (DNSParseResult *)IOMallocAligned(allocSize, 2);
    if (m_parseResults.results == nullptr) {
        return;
    }
    m_parseResults.count = header.questions;
    bzero(m_parseResults.results, allocSize);
    
    m_parseIndex += kDNSHeaderSize;
    if (!parseQuery(header.questions, replyCode) || !parseReply(header.answers)) {
        IOFreeAligned(m_parseResults.results, allocSize);
        m_parseResults.count = 0;
        m_parseResults.results = nullptr;
        return;
    }
}

DNSResolveResults DNSResolver::getResults() {
    if (m_originPacket == nullptr || m_packetSize == 0) {
        return m_parseResults;
    }
    if (m_protocol == IPPROTO_UDP) {
        if (m_packetSize <= kDNSHeaderSize) {
            return m_parseResults;
        }
        m_parseIndex = 0;
    }
    else if (m_protocol == IPPROTO_TCP) {
        if (m_packetSize <= sizeof(UInt16) + kDNSHeaderSize) {
            return m_parseResults;
        }
        // skip the length field of the header
        m_parseIndex = sizeof(UInt16);
    }
    else {
        return m_parseResults;
    }
    
    parsePacket();
    return m_parseResults;
}
