//
//  SocketFilter.hpp
//  NuwaKext
//
//  Created by ConradSun on 2022/8/1.
//

#ifndef SocketFilter_hpp
#define SocketFilter_hpp

#include <IOKit/IOUserClient.h>
#include <sys/kpi_socketfilter.h>

class SocketFilter : public OSObject {
    OSDeclareDefaultStructors(SocketFilter);

public:
    // Used for initialization after instantiation.
    bool init() override;

    // Called automatically when retain count drops to 0.
    void free() override;
    
    // Register the socket filters.
    bool registerFilters();

    // Unregister the socket filters.
    void unregisterFilters();
    
private:
    bool registerSocketFilter(sflt_filter *filter, UInt32 handle, UInt32 domain, UInt32 proto);
    void unregisterSocketFilter(sflt_filter *filter);
    
    sflt_filter m_TCPv4Filter;
    sflt_filter m_TCPv6Filter;
    sflt_filter m_UDPv4Filter;
    sflt_filter m_UDPv6Filter;
};

extern "C" errno_t socket_attach_callback(void **cookie, socket_t socket);
extern "C" void socket_detach_callback(void *cookie, socket_t socket);
extern "C" void socket_notify_callback(void *cookie, socket_t socket, sflt_event_t event, void *param);

#endif /* SocketFilter_hpp */
