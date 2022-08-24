//
//  ProcListManager.cpp
//  NuwaKext
//
//  Created by ConradSun on 2022/8/22.
//

#include "ProcListManager.hpp"
#include "KextCommon.hpp"
#include "KextLogger.hpp"

ProcListManager* ProcListManager::m_sharedInstance = nullptr;

bool ProcListManager::init() {
    m_procList = new DriverCache<UInt64, UInt8>(kMaxCacheItems);
    return true;
}

void ProcListManager::free() {
    delete m_procList;
    m_procList = nullptr;
}

ProcListManager *ProcListManager::getInstance() {
    if (m_sharedInstance != nullptr) {
        return m_sharedInstance;
    }
    
    m_sharedInstance = new ProcListManager();
    if (!m_sharedInstance->init()) {
        Logger(LOG_ERROR, "Failed to create instance for ProcListManager.")
        return nullptr;
    }
    return m_sharedInstance;
}

void ProcListManager::release() {
    if (m_sharedInstance == nullptr) {
        return;
    }
    
    m_sharedInstance->free();
    delete m_sharedInstance;
    m_sharedInstance = nullptr;
}

bool ProcListManager::addProcess(UInt64 vnodeID, bool isWhite) {
    if (vnodeID == 0) {
        return false;
    }
    
    NuwaKextProcType procType = isWhite ? kProcWhiteType : kProcBlackType;
    m_procList->setObject(vnodeID, procType);
    return true;
}

NuwaKextProcType ProcListManager::containProcess(UInt64 vnodeID) {
    NuwaKextProcType type = kProcPlainType;
    if (vnodeID == 0) {
        return type;
    }
    
    type = (NuwaKextProcType)m_procList->getObject(vnodeID);
    return type;
}
