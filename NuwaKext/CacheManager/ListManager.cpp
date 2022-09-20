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
    m_authProcessList = new DriverCache<UInt64, UInt8>(kMaxCacheItems);
    if (m_authProcessList == nullptr) {
        return false;
    }
    m_authProcessList->zero = 0;
    
    m_filterFileList = new DriverCache<UInt64, UInt8>(kMaxCacheItems);
    if (m_filterFileList == nullptr) {
        delete m_authProcessList;
        m_authProcessList = nullptr;
        return false;
    }
    m_filterFileList->zero = 0;

    return true;
}

void ListManager::free() {
    delete m_authProcessList;
    m_authProcessList = nullptr;
    delete m_filterFileList;
    m_filterFileList = nullptr;
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

bool ListManager::updateAuthProcessList(UInt64 vnodeID, bool isWhite) {
    if (vnodeID == 0) {
        return false;
    }
    
    UInt8 procType = isWhite ? kProcWhiteType : kProcBlackType;
    return m_authProcessList->setObject(vnodeID, procType);
}

bool ListManager::updateFilterFileList(UInt64 vnodeID) {
    if (vnodeID == 0) {
        return false;
    }
    
    return m_filterFileList->setObject(vnodeID, true);
}

UInt8 ListManager::obtainAuthProcessList(UInt64 vnodeID) {
    UInt8 type = kProcPlainType;
    if (vnodeID == 0) {
        return type;
    }
    
    type = m_authProcessList->getObject(vnodeID);
    return type;
}

UInt8 ListManager::obtainFilterFileList(UInt64 vnodeID) {
    if (vnodeID == 0) {
        return false;
    }
    
    return m_filterFileList->getObject(vnodeID);
}
