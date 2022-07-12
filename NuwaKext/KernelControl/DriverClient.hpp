//
//  DriverClient.hpp
//  NuwaKext
//
//  Created by 孙康 on 2022/7/7.
//

#ifndef DriverClient_hpp
#define DriverClient_hpp

#include <IOKit/IOUserClient.h>
#include <sys/kauth.h>
#include "DriverService.hpp"

class DriverClient : public IOUserClient {
    OSDeclareDefaultStructors(DriverClient);
    
public:
    // Called as part of IOServiceOpen in clients
    bool initWithTask(task_t owningTask, void *securityID, UInt32 type) override;

    // Called after initWithTask as part of IOServiceOpen
    bool start(IOService *provider) override;

    // Called when this class is stopping
    void stop(IOService *provider) override;

    // Called when a client manually disconnects (via IOServiceClose)
    IOReturn clientClose(void) override;

    // Called when a client dies
    IOReturn clientDied(void) override;

    // Called during termination
    bool didTerminate(IOService *provider, IOOptionBits options, bool *defer) override;

    //  Called in clients with IOConnectCallScalarMethod etc. Dispatches to the requested selector using the SantaDriverMethods enum in SNTKernelCommon.
    IOReturn externalMethod(UInt32 selector, IOExternalMethodArguments *arguments, IOExternalMethodDispatch *dispatch, OSObject *target, void *reference) override;
    
    // Called during client connection.
    static IOReturn open(OSObject *target, void *reference, IOExternalMethodArguments *arguments);
    
private:
    DriverService *m_driverService;
};

#endif /* DriverClient_hpp */
