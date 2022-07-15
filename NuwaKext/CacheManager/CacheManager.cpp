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
    m_authCache = new DriverCache<UInt64, UInt8>(kMaxCacheItems);
    if (m_authCache == nullptr) {
        return false;
    }
    return true;
}

void CacheManager::free() {
    delete m_authCache;
    m_authCache = nullptr;
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

bool CacheManager::setObjectForAuthCache(UInt64 vnodeID, UInt8 result) {
    if (vnodeID == 0) {
        return false;
    }
    m_authCache->setObject(vnodeID, result);
    wakeup((void *)vnodeID);
    return true;
}

UInt8 CacheManager::getObjectForAuthCache(UInt64 vnodeID) {
    if (vnodeID == 0) {
        return 0;
    }
    return m_authCache->getObject(vnodeID);
}
