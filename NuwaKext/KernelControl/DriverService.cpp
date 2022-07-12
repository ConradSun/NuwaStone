//
//  DriverService.cpp
//  NuwaKext
//
//  Created by 孙康 on 2022/7/10.
//

#include "DriverService.hpp"
#include "KextLog.h"

OSDefineMetaClassAndStructors(DriverService, IOService);

bool DriverService::start(IOService *provider) {
    if (!IOService::start(provider)) {
        return false;
    }

    m_kauthController = new KauthController();
    if (m_kauthController == nullptr) {
        return false;
    }
    if (!m_kauthController->init() || m_kauthController->startListeners() != KERN_SUCCESS) {
        m_kauthController->release();
        m_kauthController = nullptr;
        return false;
    }
    registerService();

    KLOG(LOG_INFO, "Kext loaded with version [%s].", OSKextGetCurrentVersionString())
    return true;
}

void DriverService::stop(IOService *provider) {
    m_kauthController->stopListeners();
    m_kauthController->release();
    m_kauthController = nullptr;
    
    IOService::stop(provider);
    KLOG(LOG_INFO, "Kext unloaded successfully.")
}
