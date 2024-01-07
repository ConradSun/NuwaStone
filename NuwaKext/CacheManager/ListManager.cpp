//
//  ListManager.cpp
//  NuwaKext
//
//  Created by ConradSun on 2022/9/19.
//

#include "ListManager.hpp"
#include "KextCommon.hpp"
#include "KextLogger.hpp"

ListManager* ListManager::m_sharedInstance = nullptr;

bool ListManager::init() {
    m_allowProcList = new DriverCache<UInt64, UInt8>(kMaxCacheItems);
    if (m_allowProcList == nullptr) {
        return false;
    }
    m_allowProcList->zero = kProcPlainType;
    m_denyProcList = new DriverCache<UInt64, UInt8>(kMaxCacheItems);
    if (m_denyProcList == nullptr) {
        free();
        return false;
    }
    m_denyProcList->zero = kProcPlainType;
    
    m_muteFileList = new DriverCache<UInt64, UInt8>(kMaxCacheItems);
    if (m_muteFileList == nullptr) {
        free();
        return false;
    }
    m_muteFileList->zero = false;

    return true;
}

void ListManager::free() {
    if (m_allowProcList != nullptr) {
        delete m_allowProcList;
        m_allowProcList = nullptr;
    }
    if (m_denyProcList != nullptr) {
        delete m_denyProcList;
        m_denyProcList = nullptr;
    }
    if (m_muteFileList != nullptr) {
        delete m_muteFileList;
        m_muteFileList = nullptr;
    }
}

ListManager *ListManager::getInstance() {
    if (m_sharedInstance != nullptr) {
        return m_sharedInstance;
    }
    
    m_sharedInstance = new ListManager();
    if (!m_sharedInstance->init()) {
        Logger(LOG_ERROR, "Failed to create instance for ListManager.")
        return nullptr;
    }
    return m_sharedInstance;
}

void ListManager::release() {
    if (m_sharedInstance == nullptr) {
        return;
    }
    
    m_sharedInstance->free();
    delete m_sharedInstance;
    m_sharedInstance = nullptr;
}

bool ListManager::updateAuthProcessList(UInt64 *vnodeID, NuwaKextMuteType type) {
    if (vnodeID == nullptr) {
        return false;
    }
    
    SInt i = 0;
    NuwaKextProcType procType = kProcPlainType;
    DriverCache<UInt64, UInt8> *procList = nullptr;
    
    if (type == kAllowAuthExec) {
        procType = kProcWhiteType;
        procList = m_allowProcList;
    } else {
        procType = kProcBlackType;
        procList = m_denyProcList;
    }
    procList->clearObjects();
    while (vnodeID[i] != 0 && i < kMaxCacheItems) {
        if (!procList->setObject(vnodeID[i], procType)) {
            Logger(LOG_WARN, "Failed to update item for auth process.")
        }
        i++;
    }
    
    return true;
}

bool ListManager::updateFilterFileList(UInt64 *vnodeID, NuwaKextMuteType type) {
    if (vnodeID == nullptr) {
        return false;
    }
    
    SInt i = 0;
    m_muteFileList->clearObjects();
    while (vnodeID[i] != 0 && i < kMaxCacheItems) {
        if (!m_muteFileList->setObject(vnodeID[i], true)) {
            Logger(LOG_WARN, "Failed to update item for filtering file event.")
        }
        i++;
    }
    
    return true;
}

UInt8 ListManager::obtainAuthProcessList(UInt64 vnodeID) {
    UInt8 type = kProcPlainType;
    if (vnodeID == 0) {
        return type;
    }
    
    type = m_allowProcList->getObject(vnodeID);
    if (type == kProcPlainType) {
        type = m_denyProcList->getObject(vnodeID);
    }
    return type;
}

UInt8 ListManager::obtainFilterFileList(UInt64 vnodeID) {
    if (vnodeID == 0) {
        return false;
    }
    
    return m_muteFileList->getObject(vnodeID);
}
