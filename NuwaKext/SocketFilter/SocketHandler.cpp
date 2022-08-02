//
//  SocketHandler.cpp
//  NuwaKext
//
//  Created by ConradSun on 2022/8/1.
//

#include "SocketHandler.hpp"
#include "KextLogger.hpp"
#include <sys/proc.h>
#include <sys/kauth.h>
#include <sys/vnode.h>
#include <netinet/in.h>

OSDefineMetaClassAndStructors(SocketHandler, OSObject);

#pragma mark - Socket Handler

bool SocketHandler::init() {
    if (!OSObject::init()) {
        return false;
    }
    
    m_socket = nullptr;
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
    vfs_context_t context = vfs_context_create(NULL);
    proc_t proc = vfs_context_proc(context);
    kauth_cred_t cred = vfs_context_ucred(context);
    
    bzero(netEvent, sizeof(NuwaKextEvent));
    netEvent->eventType = action;
    netEvent->eventTime = time.tv_sec;
    
    if (proc != NULL) {
        netEvent->mainProcess.pid = proc_pid(proc);
        netEvent->mainProcess.ppid = proc_ppid(proc);
    }
    if (cred != NULL) {
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

void SocketHandler::notifySocketCallback(socket_t socket, sflt_event_t event) {
    m_socket = socket;
    NuwaKextEvent *netEvent = (NuwaKextEvent *)IOMallocAligned(sizeof(NuwaKextEvent), 2);
    if (netEvent == nullptr) {
        return;
    }
    
    if (fillNetEventInfo(netEvent, kActionNotifyNetworkAccess) == 0) {
        m_eventDispatcher->postToNotifyQueue(netEvent);
    }
    IOFreeAligned(netEvent, sizeof(NuwaKextEvent));
}
