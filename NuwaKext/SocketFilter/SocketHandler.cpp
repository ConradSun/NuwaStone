//
//  SocketHandler.cpp
//  NuwaKext
//
//  Created by ConradSun on 2022/8/1.
//

#include "SocketHandler.hpp"
#include "DNSResolver.hpp"
#include "KextLogger.hpp"
#include <sys/proc.h>
#include <sys/kauth.h>
#include <sys/vnode.h>
#include <sys/kpi_mbuf.h>

OSDefineMetaClassAndStructors(SocketHandler, OSObject);

#pragma mark - Socket Handler

bool SocketHandler::init() {
    if (!OSObject::init()) {
        return false;
    }
    
    m_socket = nullptr;
    bzero(&m_procInfo, sizeof(NuwaKextProc));
    bzero(&m_localAddr, sizeof(sockaddr));
    bzero(&m_remoteAddr, sizeof(sockaddr));
    
    m_cacheManager = CacheManager::getInstance();
    if (m_cacheManager == nullptr) {
        return false;
    }
    m_eventDispatcher = EventDispatcher::getInstance();
    if (m_eventDispatcher == nullptr) {
        return false;
    }
    return true;
}

void SocketHandler::free() {
    m_eventDispatcher = nullptr;
    m_cacheManager = nullptr;
    OSObject::free();
}

errno_t SocketHandler::fillBasicInfo(NuwaKextEvent *netEvent, NuwaKextAction action) {
    timeval time;
    microtime(&time);
    vfs_context_t context = vfs_context_create(nullptr);
    proc_t proc = vfs_context_proc(context);
    kauth_cred_t cred = vfs_context_ucred(context);
    
    netEvent->eventType = action;
    netEvent->eventTime = time.tv_sec;
    
    if (proc != nullptr) {
        netEvent->mainProcess.pid = proc_pid(proc);
        netEvent->mainProcess.ppid = proc_ppid(proc);
    }
    if (cred != nullptr) {
        netEvent->mainProcess.euid = kauth_cred_getuid(cred);
        netEvent->mainProcess.ruid = kauth_cred_getruid(cred);
        netEvent->mainProcess.egid = kauth_cred_getgid(cred);
        netEvent->mainProcess.rgid = kauth_cred_getrgid(cred);
    }
    
    vfs_context_rele(context);
    return 0;
}

errno_t SocketHandler::fillConnectionInfo(NuwaKextEvent *netEvent) {
    errno_t error = 0;
    int sockType = 0;
    int length = sizeof(sockType);
    
    if (m_localAddr.sa_family == 0) {
        error = sock_getsockname(m_socket, &m_localAddr, sizeof(sockaddr));
        if (error != 0) {
            Logger(LOG_ERROR, "Failed to get sock name with error [%d].", error)
            return error;
        }
    }
    if (m_remoteAddr.sa_family == 0) {
        error = sock_getpeername(m_socket, &m_remoteAddr, sizeof(sockaddr));
        if (error != 0 && error != ENOTCONN) {
            Logger(LOG_ERROR, "Failed to get peer name with error [%d].", error)
            return error;
        }
    }
    
    error = sock_getsockopt(m_socket, SOL_SOCKET, SO_TYPE, &sockType, &length);
    if (error != 0) {
        return error;
    }
    switch (sockType) {
        case SOCK_STREAM:
            netEvent->netAccess.protocol = IPPROTO_TCP;
            break;
        case SOCK_DGRAM:
            netEvent->netAccess.protocol = IPPROTO_UDP;
            break;
        default:
            return EINVAL;
    }
    
    netEvent->netAccess.localAddr = m_localAddr;
    netEvent->netAccess.remoteAddr = m_remoteAddr;
    
    return 0;
}

errno_t SocketHandler::fillNetEventInfo(NuwaKextEvent *netEvent, NuwaKextAction action) {
    errno_t error = 0;
    
    error = fillBasicInfo(netEvent, action);
    if (error != 0) {
        Logger(LOG_WARN, "Failed to fill basic info [%d].", error)
        return error;
    }
    
    error = fillConnectionInfo(netEvent);
    if (error != 0) {
        Logger(LOG_WARN, "Failed to fill connection info [%d].", error)
        return error;
    }
    
    return error;
}

void SocketHandler::fillInfoFromCache(NuwaKextEvent *netEvent) {
    if (netEvent->mainProcess.pid != 0) {
        return;
    }
    
    netEvent->mainProcess = m_procInfo;
    if (m_procInfo.pid != 0) {
        return;
    }
    
    if (netEvent->eventType == kActionNotifyNetworkAccess) {
        if (netEvent->netAccess.protocol == IPPROTO_TCP) {
            UInt16 port = ((UInt16)netEvent->netAccess.localAddr.sa_data[0] << 8) | (UInt8)netEvent->netAccess.localAddr.sa_data[1];
            UInt64 value = m_cacheManager->obtainPortBindCache(port);
            netEvent->mainProcess.pid = value >> 32;
            netEvent->mainProcess.ppid = (value << 32) >> 32;
        }
    } else if (netEvent->eventType == kActionNotifyDnsQuery) {
        UInt64 addr = *(UInt64 *)&netEvent->netAccess.remoteAddr.sa_data[2];
        UInt64 value = m_cacheManager->obtainDnsOutCache(addr);
        netEvent->mainProcess.pid = value >> 32;
        netEvent->mainProcess.ppid = (value << 32) >> 32;
    }
}

void SocketHandler::bindSocketCallback(socket_t socket, const sockaddr *to) {
    m_socket = socket;
    m_localAddr = *to;
    NuwaKextEvent netEvent = {};
    if (fillNetEventInfo(&netEvent, kActionNotifyNetworkAccess) != 0) {
        return;
    }
    
    m_procInfo = netEvent.mainProcess;
    if (netEvent.netAccess.protocol == IPPROTO_TCP) {
        UInt16 port = ((UInt16)m_localAddr.sa_data[0] << 8) | (UInt8)m_localAddr.sa_data[1];
        UInt64 value = ((UInt64)netEvent.mainProcess.pid << 32) | netEvent.mainProcess.ppid;
        m_cacheManager->updatePortBindCache(port, value);
    }
}

void SocketHandler::notifySocketCallback(socket_t socket, sflt_event_t event) {
    m_socket = socket;
    NuwaKextEvent *netEvent = (NuwaKextEvent *)IOMallocAligned(sizeof(NuwaKextEvent), 2);
    if (netEvent == nullptr) {
        return;
    }
    
    bzero(netEvent, sizeof(NuwaKextEvent));
    if (fillNetEventInfo(netEvent, kActionNotifyNetworkAccess) == 0) {
        fillInfoFromCache(netEvent);
        m_eventDispatcher->postToNotifyQueue(netEvent);
    }
    IOFreeAligned(netEvent, sizeof(NuwaKextEvent));
}

void SocketHandler::connectSocketCallback(socket_t socket, const sockaddr *to) {
    NuwaKextEvent netEvent = {};
    if (fillBasicInfo(&netEvent, kActionNotifyNetworkAccess) == 0) {
        m_procInfo = netEvent.mainProcess;
    }
}

void SocketHandler::inboundSocketCallback(socket_t socket, mbuf_t *data, const sockaddr *from) {
    m_socket = socket;
    mbuf_t packet = *data;
    if (from != nullptr) {
        m_remoteAddr = *from;
    }
    
    NuwaKextEvent event = {};
    if (fillConnectionInfo(&event) != 0) {
        Logger(LOG_ERROR, "Failed to fill info for inbound flow.")
        return;
    }
    UInt16 port = ((UInt16)m_remoteAddr.sa_data[0] << 8) | (UInt8)m_remoteAddr.sa_data[1];
    if (port != 53) {
        return;
    }
    
    while (packet != nullptr && mbuf_type(packet) != MBUF_TYPE_DATA) {
        packet = mbuf_next(packet);
    }
    size_t size = mbuf_len(packet);
    DNSResolver resolver((char *)mbuf_data(packet), size, event.netAccess.protocol);
    DNSResolveResults results = resolver.getResults();
    if (results.count == 0 || results.results == nullptr) {
        return;
    }
    
    NuwaKextEvent *netEvent = (NuwaKextEvent *)IOMallocAligned(sizeof(NuwaKextEvent), 2);
    if (netEvent == nullptr) {
        return;
    }
    for (UInt16 i = 0; i < results.count; ++i) {
        if (strlen(results.results[i].queryResult) == 0) {
            continue;
        }
        bzero(netEvent, sizeof(NuwaKextEvent));
        if (fillBasicInfo(netEvent, kActionNotifyDnsQuery) == 0) {
            fillInfoFromCache(netEvent);
            netEvent->dnsQuery.queryStatus = results.results[i].replyCode;
            strlcpy(netEvent->dnsQuery.domainName, results.results[i].domainName, kMaxNameLength);
            strlcpy(netEvent->dnsQuery.queryResult, results.results[i].queryResult, kMaxPathLength);
            m_eventDispatcher->postToNotifyQueue(netEvent);
        }
    }
    
    IOFreeAligned(netEvent, sizeof(NuwaKextEvent));
}

void SocketHandler::outboundSocketCallback(socket_t socket, const sockaddr *to) {
    m_socket = socket;
    if (to != nullptr) {
        m_remoteAddr = *to;
    }
    
    NuwaKextEvent event = {};
    if (fillBasicInfo(&event, kActionNotifyDnsQuery) != 0) {
        Logger(LOG_ERROR, "Failed to fill info for outbound flow.")
        return;
    }
    
    UInt16 port = ((UInt16)m_remoteAddr.sa_data[0] << 8) | (UInt8)m_remoteAddr.sa_data[1];
    if (port != 53) {
        return;
    }
    UInt64 addr = *(UInt64 *)&m_remoteAddr.sa_data[2];
    UInt64 value = ((UInt64)event.mainProcess.pid << 32) | event.mainProcess.ppid;
    m_cacheManager->updateDnsOutCache(addr, value);
}
