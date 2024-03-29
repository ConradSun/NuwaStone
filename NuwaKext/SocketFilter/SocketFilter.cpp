//
//  SocketFilter.cpp
//  NuwaKext
//
//  Created by ConradSun on 2022/8/1.
//

#include "SocketFilter.hpp"
#include "SocketHandler.hpp"
#include "KextCommon.hpp"
#include "KextLogger.hpp"
#include <sys/proc.h>
#include <sys/errno.h>

OSDefineMetaClassAndStructors(SocketFilter, OSObject);

static SInt32 s_activeEventCount = 0;
static const UInt32 s_TCPv4FilterHandle = kBaseFilterHandle - (AF_INET + IPPROTO_TCP);
static const UInt32 s_TCPv6FilterHandle = kBaseFilterHandle - (AF_INET6 + IPPROTO_TCP);
static const UInt32 s_UDPv4FilterHandle = kBaseFilterHandle - (AF_INET + IPPROTO_UDP);
static const UInt32 s_UDPv6FilterHandle = kBaseFilterHandle - (AF_INET6 + IPPROTO_UDP);

#pragma mark - Socket Filter

bool SocketFilter::init() {
    if (!OSObject::init()) {
        return false;
    }
    return true;
}

void SocketFilter::free() {
    OSObject::free();
}

bool SocketFilter::registerSocketFilter(sflt_filter *filter, UInt32 handle, UInt32 domain, UInt32 proto) {
    errno_t error = 0;
    UInt32 type = 0;
    bzero(filter, sizeof(sflt_filter));
    
    filter->sf_handle = handle;
    filter->sf_flags = SFLT_GLOBAL;
    filter->sf_name = (char *)kSocketFilterName;
    filter->sf_attach = socket_attach_callback;
    filter->sf_detach = socket_detach_callback;
    filter->sf_bind = socket_bind_callback;
    filter->sf_notify = socket_notify_callback;
    filter->sf_data_in = socket_data_in_callback;
    filter->sf_data_out = socket_data_out_callback;
    
    switch (proto) {
        case IPPROTO_TCP:
            type = SOCK_STREAM;
            filter->sf_connect_out = socket_connect_out_callback;
            break;
        case IPPROTO_UDP:
            type = SOCK_DGRAM;
            break;
        default:
            break;
    }
    
    error = sflt_register(filter, domain, type, proto);
    if (error != 0) {
        filter->sf_handle = kBaseFilterHandle;
        Logger(LOG_ERROR, "Failed to register filter with error [%d].", error)
        return false;
    }
    
    return true;
}

void SocketFilter::unregisterSocketFilter(sflt_filter *filter) {
    errno_t error = 0;
    
    if (filter->sf_handle != kBaseFilterHandle) {
        error = sflt_unregister(filter->sf_handle);
        filter->sf_handle = kBaseFilterHandle;
        if (error != 0) {
            Logger(LOG_ERROR, "Failed to unregister filter with error [%d].", error)
        }
    }
}

bool SocketFilter::registerFilters() {
    if (!registerSocketFilter(&m_TCPv4Filter, s_TCPv4FilterHandle, AF_INET, IPPROTO_TCP)) {
        return false;
    }
    if (!registerSocketFilter(&m_TCPv6Filter, s_TCPv6FilterHandle, AF_INET6, IPPROTO_TCP)) {
        unregisterSocketFilter(&m_TCPv4Filter);
        return false;
    }
    
    if (!registerSocketFilter(&m_UDPv4Filter, s_UDPv4FilterHandle, AF_INET, IPPROTO_UDP)) {
        unregisterSocketFilter(&m_TCPv4Filter);
        unregisterSocketFilter(&m_TCPv6Filter);
        return false;
    }
    if (!registerSocketFilter(&m_UDPv6Filter, s_UDPv6FilterHandle, AF_INET6, IPPROTO_UDP)) {
        unregisterSocketFilter(&m_TCPv4Filter);
        unregisterSocketFilter(&m_TCPv6Filter);
        unregisterSocketFilter(&m_UDPv4Filter);
        return false;
    }
    
    return true;
}

void SocketFilter::unregisterFilters() {
    static timespec wait = {
        .tv_sec = 0,
        .tv_nsec = 1000000
    };
    
    unregisterSocketFilter(&m_TCPv4Filter);
    unregisterSocketFilter(&m_TCPv6Filter);
    unregisterSocketFilter(&m_UDPv4Filter);
    unregisterSocketFilter(&m_UDPv6Filter);
    
    while (s_activeEventCount > 0) {
        msleep(nullptr, nullptr, 0, "wait for socket filters stopped", &wait);
    }
}

#pragma mark - Callback Methods

extern "C"
errno_t socket_attach_callback(void **cookie, socket_t socket) {
    SocketHandler *handler = new SocketHandler();
    if (handler == nullptr) {
        return ENOMEM;
    }
    handler->init();
    *cookie = handler;
    return 0;
}

extern "C"
void socket_detach_callback(void *cookie, socket_t socket) {
    SocketHandler *handler = reinterpret_cast<SocketHandler *>(cookie);
    handler->release();
    cookie = nullptr;
}

extern "C"
void socket_notify_callback(void *cookie, socket_t socket, sflt_event_t event, void *param) {
    if (socket == nullptr || cookie == nullptr || event != sock_evt_connected) {
        return;
    }
    
    SocketHandler *handler = reinterpret_cast<SocketHandler *>(cookie);
    OSIncrementAtomic(&s_activeEventCount);
    handler->notifySocketCallback(socket, event);
    OSDecrementAtomic(&s_activeEventCount);
}

extern "C"
errno_t socket_bind_callback(void *cookie, socket_t socket, const struct sockaddr *to) {
    if (socket == nullptr || cookie == nullptr) {
        return EINVAL;
    }
    
    SocketHandler *handler = reinterpret_cast<SocketHandler *>(cookie);
    OSIncrementAtomic(&s_activeEventCount);
    handler->bindSocketCallback(socket, to);
    OSDecrementAtomic(&s_activeEventCount);
    
    return 0;
}

extern "C"
errno_t socket_connect_out_callback(void *cookie, socket_t socket, const struct sockaddr *to) {
    if (socket == nullptr || cookie == nullptr) {
        return EINVAL;
    }

    SocketHandler *handler = reinterpret_cast<SocketHandler *>(cookie);
    OSIncrementAtomic(&s_activeEventCount);
    handler->connectSocketCallback(socket, to);
    OSDecrementAtomic(&s_activeEventCount);

    return 0;
}

extern "C"
errno_t socket_data_in_callback(void *cookie, socket_t socket, const struct sockaddr *from, mbuf_t *data, mbuf_t *control, sflt_data_flag_t flags) {
    if (socket == nullptr || cookie == nullptr || data == nullptr) {
        return EINVAL;
    }
    
    SocketHandler *handler = reinterpret_cast<SocketHandler *>(cookie);
    OSIncrementAtomic(&s_activeEventCount);
    handler->inboundSocketCallback(socket, data, from);
    OSDecrementAtomic(&s_activeEventCount);
    
    return 0;
}

extern "C"
errno_t socket_data_out_callback(void *cookie, socket_t socket, const struct sockaddr *to, mbuf_t *data, mbuf_t *control, sflt_data_flag_t flags) {
    if (socket == nullptr || cookie == nullptr) {
        return EINVAL;
    }
    
    SocketHandler *handler = reinterpret_cast<SocketHandler *>(cookie);
    OSIncrementAtomic(&s_activeEventCount);
    handler->outboundSocketCallback(socket, to);
    OSDecrementAtomic(&s_activeEventCount);
    
    return 0;
}
