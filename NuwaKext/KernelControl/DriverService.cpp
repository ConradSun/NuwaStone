//
//  DriverService.cpp
//  NuwaKext
//
//  Created by 孙康 on 2022/7/10.
//

#include "DriverService.hpp"
#include "KextLogger.hpp"

UInt32 g_logLevel = LOG_INFO;
OSDefineMetaClassAndStructors(DriverService, IOService);

void DriverService::clearInstances() {
    if (m_cacheManager != nullptr) {
        m_cacheManager->release();
        m_cacheManager = nullptr;
    }
    
    if (m_eventDispatcher != nullptr) {
        m_eventDispatcher->release();
        m_eventDispatcher = nullptr;
    }
    
    if (m_kauthController != nullptr) {
        m_kauthController->release();
        m_kauthController = nullptr;
    }
}

bool DriverService::start(IOService *provider) {
    if (!IOService::start(provider)) {
        return false;
    }

    m_cacheManager = CacheManager::getInstance();
    m_eventDispatcher = EventDispatcher::getInstance();
    m_kauthController = new KauthController();
    if (m_cacheManager == nullptr || m_eventDispatcher == nullptr || m_kauthController == nullptr) {
        clearInstances();
        return false;
    }
    if (!m_kauthController->init() || !m_kauthController->startListeners()) {
        clearInstances();
        return false;
    }
    registerService();

    Logger(LOG_INFO, "Kext loaded with version [%s].", OSKextGetCurrentVersionString())
    return true;
}

void DriverService::stop(IOService *provider) {
    m_kauthController->stopListeners();
    clearInstances();
    IOService::stop(provider);
    Logger(LOG_INFO, "Kext unloaded successfully.")
}
