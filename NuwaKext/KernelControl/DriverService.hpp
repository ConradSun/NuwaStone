//
//  DriverService.hpp
//  NuwaKext
//
//  Created by 孙康 on 2022/7/10.
//

#ifndef DriverService_hpp
#define DriverService_hpp

#include <IOKit/IOService.h>
#include <libkern/OSKextLib.h>

class DriverService : public IOService {
    OSDeclareDefaultStructors(DriverService);

    public:
    //  Called by the kernel when the kext is loaded
    bool start(IOService *provider) override;

    //  Called by the kernel when the kext is unloaded
    void stop(IOService *provider) override;
};

#endif /* DriverService_hpp */
