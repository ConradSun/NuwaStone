//
//  DriverClient.hpp
//  NuwaKext
//
//  Created by 孙康 on 2022/7/7.
//

#ifndef DriverClient_hpp
#define DriverClient_hpp

#include "CacheManager.hpp"
#include "DriverService.hpp"
#include "EventDispatcher.hpp"
#include <sys/kauth.h>
#include <IOKit/IOUserClient.h>

class DriverClient : public IOUserClient {
    OSDeclareDefaultStructors(DriverClient);
    
public:
    // Called as part of IOServiceOpen in clients.
    bool initWithTask(task_t owningTask, void *securityID, UInt32 type) override;

    // Called after initWithTask as part of IOServiceOpen.
    bool start(IOService *provider) override;

    // Called when this class is stopping.
    void stop(IOService *provider) override;

    // Called when a client manually disconnects (via IOServiceClose).
    IOReturn clientClose(void) override;

    // Called when a client dies.
    IOReturn clientDied(void) override;

    // Called during termination.
    bool didTerminate(IOService *provider, IOOptionBits options, bool *defer) override;

    // Called in clients with IOConnectSetNotificationPort.
    IOReturn registerNotificationPort(mach_port_t port, UInt32 type, UInt32 refCon) override;

    // Called in clients with IOConnectMapMemory.
    IOReturn clientMemoryForType(UInt32 type, IOOptionBits *options, IOMemoryDescriptor **memory) override;

    // Called in clients with IOConnectCallScalarMethod etc. Dispatches to the requested selector.
    IOReturn externalMethod(UInt32 selector, IOExternalMethodArguments *arguments, IOExternalMethodDispatch *dispatch, OSObject *target, void *reference) override;

    // Called during client connection.
    static IOReturn open(OSObject *target, void *reference, IOExternalMethodArguments *arguments);
    
    // Called by daemon to allow a binary.
    static IOReturn allowBinary(OSObject *target, void *reference, IOExternalMethodArguments *arguments);
    
    // Called by daemon to deny a binary.
    static IOReturn denyBinary(OSObject *target, void *reference, IOExternalMethodArguments *arguments);

    // Called when the kext log level is setted.
    static IOReturn setLogLevel(OSObject* target, void* reference, IOExternalMethodArguments* arguments);
    
private:
    CacheManager *m_cacheManager;
    EventDispatcher *m_eventDispatcher;
    DriverService *m_driverService;
};

#endif /* DriverClient_hpp */
