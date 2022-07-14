//
//  DriverService.cpp
//  NuwaKext
//
//  Created by 孙康 on 2022/7/10.
//

#include "DriverService.hpp"
#include "KextLog.hpp"

UInt32 g_logLevel = Info;
OSDefineMetaClassAndStructors(DriverService, IOService);

bool DriverService::start(IOService *provider) {
    if (!IOService::start(provider)) {
        return false;
    }

    m_eventDispatcher = EventDispatcher::getInstance();
    if (m_eventDispatcher == nullptr) {
        return false;
    }
    
    m_kauthController = new KauthController();
    if (m_kauthController == nullptr) {
        return false;
    }
    if (!m_kauthController->init() || !m_kauthController->startListeners()) {
        m_kauthController->release();
        m_kauthController = nullptr;
        
        m_eventDispatcher->release();
        m_eventDispatcher = nullptr;
        return false;
    }
    registerService();

    KLOG(Info, "Kext loaded with version [%s].", OSKextGetCurrentVersionString())
    return true;
}

void DriverService::stop(IOService *provider) {
    m_kauthController->stopListeners();
    m_kauthController->release();
    m_kauthController = nullptr;
    
    if (m_eventDispatcher != nullptr) {
        m_eventDispatcher->release();
        m_eventDispatcher = nullptr;
    }
    
    IOService::stop(provider);
    KLOG(Info, "Kext unloaded successfully.")
}
