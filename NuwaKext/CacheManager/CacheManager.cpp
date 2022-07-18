//
//  CacheManager.cpp
//  NuwaKext
//
//  Created by 孙康 on 2022/7/14.
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
    m_authResultCache = new DriverCache<UInt64, UInt8>(kMaxCacheItems);
    if (m_authResultCache == nullptr) {
        return false;
    }
    m_authExecCache = new DriverCache<UInt64, UInt64>(kMaxCacheItems);
    if (m_authExecCache == nullptr) {
        delete m_authResultCache;
        m_authResultCache = nullptr;
        return false;
    }
    return true;
}

void CacheManager::free() {
    delete m_authResultCache;
    m_authResultCache = nullptr;
    delete m_authExecCache;
    m_authExecCache = nullptr;
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

bool CacheManager::setForAuthResultCache(UInt64 vnodeID, UInt8 result) {
    if (vnodeID == 0) {
        return false;
    }
    
    if (m_authResultCache->setObject(vnodeID, result)) {
        wakeup((void *)vnodeID);
        return true;
    }
    return false;
}

bool CacheManager::setForAuthExecCache(UInt64 vnodeID, UInt64 value) {
    if (vnodeID == 0) {
        return false;
    }
    
    return m_authExecCache->setObject(vnodeID, value);
}

UInt8 CacheManager::getFromAuthResultCache(UInt64 vnodeID) {
    if (vnodeID == 0) {
        return 0;
    }
    return m_authResultCache->getObject(vnodeID);
}

UInt64 CacheManager::getFromAuthExecCache(UInt64 vnodeID) {
    if (vnodeID == 0) {
        return 0;
    }
    
    return m_authExecCache->getObject(vnodeID);
}
