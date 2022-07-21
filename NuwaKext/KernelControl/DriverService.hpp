//
//  DriverService.hpp
//  NuwaKext
//
//  Created by ConradSun on 2022/7/10.
//

#ifndef DriverService_hpp
#define DriverService_hpp

#include <IOKit/IOService.h>
#include <libkern/OSKextLib.h>
#include "CacheManager.hpp"
#include "KauthController.hpp"
#include "EventDispatcher.hpp"

class DriverService : public IOService {
    OSDeclareDefaultStructors(DriverService);

public:
    // Called by the kernel when the kext is loaded
    bool start(IOService *provider) override;

    // Called by the kernel when the kext is unloaded
    void stop(IOService *provider) override;
    
private:
    void clearInstances();
    
    CacheManager *m_cacheManager;
    KauthController *m_kauthController;
    EventDispatcher *m_eventDispatcher;
    bool m_kextUnloadProtect;
};

#endif /* DriverService_hpp */
