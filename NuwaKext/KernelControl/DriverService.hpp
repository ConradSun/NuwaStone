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
#include "ListManager.hpp"
#include "KauthController.hpp"
#include "SocketFilter.hpp"
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
    ListManager *m_listManager;
    KauthController *m_kauthController;
    SocketFilter *m_socketFilter;
    EventDispatcher *m_eventDispatcher;
};

#endif /* DriverService_hpp */
