//
//  DNSResolver.hpp
//  NuwaKext
//
//  Created by ConradSun on 2022/8/30.
//

#ifndef DNSResolver_hpp
#define DNSResolver_hpp

#include "KextCommon.hpp"

/**
 *  desc：Structure of DNS packet
 *  UInt16      Transaction ID
 *  UInt16      Flags
 *  UInt16      Questions
 *  UInt16      Answer RRs
 *  UInt16      Authority RRs
 *  UInt16      Additional RRs
 *  variable    Queries
 *  variable    Answers
 *  variable    Authortative name servers
 *  variable    Additional records
 */

static const UInt8 kDNSHeaderSize = 12;
static const UInt8 kDNSQuerySize = 4;
static const UInt8 kDNSReplySize = 10;
static const UInt8 kMaxNameCount = 32;

/**
* @berif DNS Type
*/
typedef enum {
    kDNSType_A      = 1,    // IPv4 Address
    kDNSType_CNAME  = 5,    // Canonical Name
    kDNSType_AAAA   = 28,   // IPv6 Address
} DNSTypeCode;

/**
* @berif DNS Class
*/
typedef enum {
    kDNSClass_IN    = 1,    // Internet
    kDNSClass_CS    = 2,    // CSNET
    kDNSClass_CH    = 3,    // CHAOS
    kDNSClass_HS    = 4,    // Hesiod
    kDNSClass_NONE  = 254,  // Used in DNS UPDATE [RFC 2136]
    kDNSClass_ANY   = 255,  // Not a DNS class, but a DNS query class, meaning "all classes"
} DNSClassCode;

#pragma pack(1)

/**
* @berif Header of DNS message
*/
typedef struct {
    UInt16 transID;
    UInt16 flags;
    UInt16 questions;
    UInt16 answers;
    UInt16 authorities;
    UInt16 additionals;
} DNSMessageHeader;

/**
* @berif Info of DNS query
*/
typedef struct {
    UInt16 DNSType;
    UInt16 DNSClass;
} DNSQueryInfo;

/**
* @berif Info of DNS response
*/
typedef struct {
    UInt16 DNSType;
    UInt16 DNSClass;
    UInt32 liveTime;
    UInt16 length;
} DNSResponseInfo;

#pragma pack()

/**
* @berif Parse result of one item of DNS response
*/
typedef struct {
    UInt16 replyCode;
    UInt16 replyType;
    char domainName[kMaxNameLength];
    char queryResult[kMaxPathLength];
} DNSParseResult;

/**
* @berif Parse results of DNS message
*/
typedef struct {
    UInt16 count;
    DNSParseResult *results;
} DNSResolveResults;

class DNSResolver {
    typedef struct {
        char *domainName;
        UInt16 index;
    } DNSDomainMap;

public:
    DNSResolver(const char *packet, size_t size, UInt8 protocol);
    ~DNSResolver();
    
    DNSResolveResults getResults();
    
private:
    bool setDoaminMap(const char *domainName, UInt16 index);
    SInt16 getDomainIndex(const char *domainName);
    
    bool parseDomainName(const char *nameBegin, char *domainName, UInt16 nameSize);
    bool processReplyResult(const char *domain, const char *result, UInt16 type);
    bool parseReplyItem(DNSParseResult *result);
    bool parseQuery(UInt16 queryCount, UInt16 replyCode);
    bool parseReply(UInt16 replyCount);
    void parsePacket();
    
    const char *m_originPacket;
    size_t m_packetSize;
    UInt8 m_protocol;
    UInt16 m_parseIndex;
    DNSDomainMap m_domainMap[kMaxNameCount];
    DNSResolveResults m_parseResults;
};

#endif /* DNSResolver_hpp */
