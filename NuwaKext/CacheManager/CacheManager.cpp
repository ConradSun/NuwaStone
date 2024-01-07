//
//  CacheManager.cpp
//  NuwaKext
//
//  Created by ConradSun on 2022/7/14.
//

#include "CacheManager.hpp"
#include "KextCommon.hpp"
#include "KextLogger.hpp"
#include <sys/proc.h>

lck_attr_t *g_driverLockAttr = lck_attr_alloc_init();
lck_grp_attr_t *g_driverLockGrpAttr = lck_grp_attr_alloc_init();
lck_grp_t *g_driverLockGrp = lck_grp_alloc_init("nuwa-locks", g_driverLockGrpAttr);

CacheManager* CacheManager::m_sharedInstance = nullptr;

bool CacheManager::init() {
    // Pair VnodeID: Auth Result
    m_authResultCache = new DriverCache<UInt64, UInt8>(kMaxCacheItems);
    if (m_authResultCache == nullptr) {
        return false;
    }
    m_authResultCache->zero = 0;
    
    // Pair VnodeID: pid-32bit|ppid-32bit
    m_authExecCache = new DriverCache<UInt64, UInt64>(kMaxCacheItems);
    if (m_authExecCache == nullptr) {
        free();
        return false;
    }
    m_authExecCache->zero = 0;
    
    // Pair Port: pid-32bit|ppid-32bit
    m_portBindCache = new DriverCache<UInt16, UInt64>(kMaxCacheItems);
    if (m_portBindCache == nullptr) {
        free();
        return false;
    }
    m_portBindCache->zero = 0;
    
    // Pair Addr: pid-32bit|ppid-32bit
    m_dnsOutCache = new DriverCache<UInt64, UInt64>(kMaxCacheItems);
    if (m_dnsOutCache == nullptr) {
        free();
        return false;
    }
    m_dnsOutCache->zero = 0;

    return true;
}

void CacheManager::free() {
    if (m_authResultCache != nullptr) {
        delete m_authResultCache;
        m_authResultCache = nullptr;
    }
    if (m_authExecCache != nullptr) {
        delete m_authExecCache;
        m_authExecCache = nullptr;
    }
    if (m_portBindCache != nullptr) {
        delete m_portBindCache;
        m_portBindCache = nullptr;
    }
    if (m_dnsOutCache != nullptr) {
        delete m_dnsOutCache;
        m_dnsOutCache = nullptr;
    }
}

CacheManager *CacheManager::getInstance() {
    if (m_sharedInstance != nullptr) {
        return m_sharedInstance;
    }
    
    m_sharedInstance = new CacheManager();
    if (!m_sharedInstance->init()) {
        Logger(LOG_ERROR, "Failed to create instance for CacheManager.")
        return nullptr;
    }
    return m_sharedInstance;
}

void CacheManager::release() {
    if (m_sharedInstance == nullptr) {
        return;
    }
    
    m_sharedInstance->free();
    delete m_sharedInstance;
    m_sharedInstance = nullptr;
}

bool CacheManager::updateAuthResultCache(UInt64 vnodeID, UInt8 result) {
    if (vnodeID == 0) {
        return false;
    }
    
    if (m_authResultCache->setObject(vnodeID, result)) {
        // Wake up from sleep in vnode callback
        wakeup((void *)vnodeID);
        return true;
    }
    return false;
}

bool CacheManager::updateAuthExecCache(UInt64 vnodeID, UInt64 value) {
    if (vnodeID == 0) {
        return false;
    }
    
    return m_authExecCache->setObject(vnodeID, value);
}

bool CacheManager::updatePortBindCache(UInt16 port, UInt64 value) {
    if (port == 0) {
        return false;
    }
    
    return m_portBindCache->setObject(port, value);
}

bool CacheManager::updateDnsOutCache(UInt64 addr, UInt64 value) {
    if (addr == 0) {
        return false;
    }
    
    return m_dnsOutCache->setObject(addr, value);
}

UInt8 CacheManager::obtainAuthResultCache(UInt64 vnodeID) {
    if (vnodeID == 0) {
        return 0;
    }
    return m_authResultCache->getObject(vnodeID);
}

UInt64 CacheManager::obtainAuthExecCache(UInt64 vnodeID) {
    if (vnodeID == 0) {
        return 0;
    }
    
    return m_authExecCache->getObject(vnodeID);
}

UInt64 CacheManager::obtainPortBindCache(UInt16 port) {
    if (port == 0) {
        return 0;
    }
    
    return m_portBindCache->getObject(port);
}

UInt64 CacheManager::obtainDnsOutCache(UInt64 addr) {
    if (addr == 0) {
        return 0;
    }
    
    return m_dnsOutCache->getObject(addr);
}
