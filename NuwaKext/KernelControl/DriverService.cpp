//
//  DriverService.cpp
//  NuwaKext
//
//  Created by ConradSun on 2022/7/10.
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
    
    if (m_listManager != nullptr) {
        m_listManager->release();
        m_listManager = nullptr;
    }
    
    if (m_eventDispatcher != nullptr) {
        m_eventDispatcher->release();
        m_eventDispatcher = nullptr;
    }
    
    if (m_kauthController != nullptr) {
        m_kauthController->release();
        m_kauthController = nullptr;
    }
    
    if (m_socketFilter != nullptr) {
        m_socketFilter->release();
        m_socketFilter = nullptr;
    }
}

bool DriverService::start(IOService *provider) {
    if (!IOService::start(provider)) {
        return false;
    }

    m_cacheManager = CacheManager::getInstance();
    m_listManager = ListManager::getInstance();
    m_eventDispatcher = EventDispatcher::getInstance();
    m_kauthController = new KauthController();
    m_socketFilter = new SocketFilter();
    if (m_cacheManager == nullptr || m_listManager == nullptr || m_eventDispatcher == nullptr || m_kauthController == nullptr || m_socketFilter == nullptr) {
        clearInstances();
        return false;
    }
    if (!m_kauthController->init() || !m_socketFilter->init()) {
        clearInstances();
        return false;
    }
    if (!m_kauthController->startListeners() || !m_socketFilter->registerFilters()) {
        clearInstances();
        return false;
    }

    registerService();

    Logger(LOG_INFO, "Kext loaded with version [%s].", OSKextGetCurrentVersionString())
    return true;
}

void DriverService::stop(IOService *provider) {
    m_kauthController->stopListeners();
    m_socketFilter->unregisterFilters();
    clearInstances();
    IOService::stop(provider);
    Logger(LOG_INFO, "Kext unloaded successfully.")
}

KauthController *DriverService::getKauthController() const {
    return m_kauthController;
}

SocketFilter *DriverService::getSocketFilter() const {
    return m_socketFilter;
}
