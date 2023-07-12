//
//  DriverClient.cpp
//  NuwaKext
//
//  Created by ConradSun on 2022/7/7.
//

#include "DriverClient.hpp"
#include "KextCommon.hpp"
#include "KextLogger.hpp"

OSDefineMetaClassAndStructors(DriverClient, IOUserClient);

#pragma mark Driver Management

bool DriverClient::initWithTask(task_t owningTask, void *securityID, UInt32 type) {
    if (clientHasPrivilege(owningTask, kIOClientPrivilegeAdministrator) != KERN_SUCCESS) {
        Logger(LOG_INFO, "Unprivileged client attempted to connect.")
    }
    if (!IOUserClient::initWithTask(owningTask, securityID, type)) {
        return false;
    }

    Logger(LOG_INFO, "Driver client init successfully.")
    return true;
}

bool DriverClient::start(IOService *provider) {
    m_driverService = OSDynamicCast(DriverService, provider);
    if (m_driverService == nullptr) {
        return false;
    }
    m_cacheManager = CacheManager::getInstance();
    if (m_cacheManager == nullptr) {
        return false;
    }
    m_listManager = ListManager::getInstance();
    if (m_listManager == nullptr) {
        return false;
    }
    m_eventDispatcher = EventDispatcher::getInstance();
    if (m_eventDispatcher == nullptr) {
        return false;
    }
    return IOUserClient::start(provider);
}

void DriverClient::stop(IOService *provider) {
    m_eventDispatcher = nullptr;
    m_listManager = nullptr;
    m_cacheManager = nullptr;
    m_driverService = nullptr;
    IOUserClient::stop(provider);
}

IOReturn DriverClient::clientDied() {
    m_eventDispatcher->setConnectionStatus(false);
    Logger(LOG_INFO, "Client died.")
    return terminate(0) ? kIOReturnSuccess : kIOReturnError;
}

IOReturn DriverClient::clientClose() {
    m_eventDispatcher->setConnectionStatus(false);
    if (m_driverService != nullptr && m_driverService->isOpen(this)) {
        m_driverService->close(this);
    }
    
    Logger(LOG_INFO, "Client disconnected.")
    return terminate(0) ? kIOReturnSuccess : kIOReturnError;
}

bool DriverClient::didTerminate(IOService *provider, IOOptionBits options, bool *defer) {
    m_eventDispatcher->setConnectionStatus(false);
    if (m_driverService != nullptr && m_driverService->isOpen(this)) {
        m_driverService->close(this);
    }
    
    Logger(LOG_INFO, "Client terminated.")
    return IOUserClient::didTerminate(provider, options, defer);
}

#pragma mark Data Queue Methods

IOReturn DriverClient::registerNotificationPort(mach_port_t port, UInt32 type, UInt32 ref) {
    if (port == MACH_PORT_NULL) {
        return kIOReturnError;
    }
    
    switch (type) {
        case kQueueTypeAuth:
        case kQueueTypeNotify:
            m_eventDispatcher->setNotificationPortForQueue(type, port);
            break;
        default:
            return kIOReturnBadArgument;
    }
    
    return kIOReturnSuccess;
}

IOReturn DriverClient::clientMemoryForType(UInt32 type, IOOptionBits *options, IOMemoryDescriptor **memory) {
    switch (type) {
        case kQueueTypeAuth:
        case kQueueTypeNotify:
            *options = 0;
            *memory = m_eventDispatcher->getMemoryDescriptorForQueue(type);
            break;
        default:
            return kIOReturnBadArgument;
    }

    (*memory)->retain();
    return kIOReturnSuccess;
}

#pragma mark Callable Methods

IOReturn DriverClient::open(OSObject *target, void *reference, IOExternalMethodArguments *arguments) {
    DriverClient *me = OSDynamicCast(DriverClient, target);
    
    if (me == nullptr) {
        return kIOReturnBadArgument;
    }
    if (me->isInactive()) {
        return kIOReturnNotAttached;
    }
    if (!me->m_driverService->open(me)) {
        Logger(LOG_ERROR, "A second client tried to connect.")
        return kIOReturnExclusiveAccess;
    }
    me->m_eventDispatcher->setConnectionStatus(true);
    
    Logger(LOG_INFO, "Client connected successfully.")
    return kIOReturnSuccess;
}

IOReturn DriverClient::allowBinary(OSObject *target, void *reference, IOExternalMethodArguments *arguments) {
    DriverClient *me = OSDynamicCast(DriverClient, target);
    if (me == nullptr) {
        return kIOReturnBadArgument;
    }
    
    UInt64 vnodeID = arguments->scalarInput[0];
    me->m_cacheManager->updateAuthResultCache(vnodeID, KAUTH_RESULT_DEFER);
    return kIOReturnSuccess;
}

IOReturn DriverClient::denyBinary(OSObject *target, void *reference, IOExternalMethodArguments *arguments) {
    DriverClient *me = OSDynamicCast(DriverClient, target);
    if (me == nullptr) {
        return kIOReturnBadArgument;
    }
    
    UInt64 vnodeID = arguments->scalarInput[0];
    me->m_cacheManager->updateAuthResultCache(vnodeID, KAUTH_RESULT_DENY);
    return kIOReturnSuccess;
}

IOReturn DriverClient::setLogLevel(OSObject* target, void* reference, IOExternalMethodArguments* arguments) {
    DriverClient *me = OSDynamicCast(DriverClient, target);
    if (me == nullptr) {
        return kIOReturnBadArgument;
    }
    
    UInt32 level = (UInt32)arguments->scalarInput[0];
    if (g_logLevel != level) {
        Logger(LOG_INFO, "Log level setted to be %d", level)
        g_logLevel = level;
    }
    return kIOReturnSuccess;
}

IOReturn DriverClient::updateMuteList(OSObject* target, void* reference, IOExternalMethodArguments* arguments) {
    DriverClient *me = OSDynamicCast(DriverClient, target);
    if (me == nullptr) {
        return kIOReturnBadArgument;
    }
    if (arguments->structureInputSize != sizeof(NuwaKextMuteInfo)) {
        return kIOReturnInvalid;
    }
    
    NuwaKextMuteInfo *info = (NuwaKextMuteInfo *)arguments->structureInput;
    // It's unsupported to filter file event by proc paths in kext for now.
    if (info->muteType == kAllowAuthExec || info->muteType == kDenyAuthExec) {
        me->m_listManager->updateAuthProcessList(info->vnodeID, info->muteType);
    } else if (info->muteType == kFilterFileByFilePath) {
        me->m_listManager->updateFilterFileList(info->vnodeID, info->muteType);
    }
    
    return kIOReturnSuccess;
}

#pragma mark Method Resolution

IOReturn DriverClient::externalMethod(UInt32 selector, IOExternalMethodArguments *arguments,
                                      IOExternalMethodDispatch *dispatch, OSObject *target, void *reference) {
    // Array of methods callable by clients.
    static IOExternalMethodDispatch sMethods[kNuwaUserClientNMethods] = {
        // Function ptr, input scalar count, input struct size, output scalar count, output struct size
        { &DriverClient::open, 0, 0, 0, 0 },
        { &DriverClient::allowBinary, 1, 0, 0, 0 },
        { &DriverClient::denyBinary, 1, 0, 0, 0 },
        { &DriverClient::setLogLevel, 1, 0, 0, 0 },
        { &DriverClient::updateMuteList, 0, sizeof(NuwaKextMuteInfo), 0, 0 }
    };

    if (selector >= static_cast<UInt32>(kNuwaUserClientNMethods)) {
        return kIOReturnBadArgument;
    }

    dispatch = &(sMethods[selector]);
    if (!target) {
        target = this;
    }
    return IOUserClient::externalMethod(selector, arguments, dispatch, target, reference);
}
