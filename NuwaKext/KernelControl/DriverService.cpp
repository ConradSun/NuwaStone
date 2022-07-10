//
//  DriverService.cpp
//  NuwaKext
//
//  Created by 孙康 on 2022/7/10.
//

#include "DriverService.hpp"
#include "KextLog.hpp"

OSDefineMetaClassAndStructors(DriverService, IOService);

bool DriverService::start(IOService *provider) {
    if (!IOService::start(provider)) {
        return false;
    }

    registerService();

    KLOG(LOG_INFO, "Kext loaded with version [%s].", OSKextGetCurrentVersionString());
    return true;
}

void DriverService::stop(IOService *provider) {
    KLOG(LOG_INFO, "Kext stopped for now.");
    IOService::stop(provider);
}
