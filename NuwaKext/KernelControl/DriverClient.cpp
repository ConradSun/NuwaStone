//
//  DriverClient.cpp
//  NuwaKext
//
//  Created by 孙康 on 2022/7/7.
//

#include "DriverClient.hpp"
#include "KextCommon.hpp"
#include "KextLog.hpp"

OSDefineMetaClassAndStructors(DriverClient, IOUserClient);

#pragma mark Driver Management

bool DriverClient::initWithTask(task_t owningTask, void *securityID, UInt32 type) {
    if (clientHasPrivilege(owningTask, kIOClientPrivilegeAdministrator) != KERN_SUCCESS) {
        KLOG(LOG_ERROR, "Unprivileged client attempted to connect.")
        return false;
    }

    if (!IOUserClient::initWithTask(owningTask, securityID, type)) {
        return false;
    }

    KLOG(LOG_INFO, "Driver client init successfully.")
    return true;
}

bool DriverClient::start(IOService *provider) {
    m_driverService = OSDynamicCast(DriverService, provider);
    if (m_driverService == nullptr) {
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
    m_driverService = nullptr;
    IOUserClient::stop(provider);
}

IOReturn DriverClient::clientDied() {
    KLOG(LOG_INFO, "Client died.")
    return terminate(0) ? kIOReturnSuccess : kIOReturnError;
}

IOReturn DriverClient::clientClose() {
    if (m_driverService != nullptr && m_driverService->isOpen(this)) {
        m_driverService->close(this);
    }
    
    KLOG(LOG_INFO, "Client disconnected.")
    return terminate(0) ? kIOReturnSuccess : kIOReturnError;
}

bool DriverClient::didTerminate(IOService *provider, IOOptionBits options, bool *defer) {
    if (m_driverService != nullptr && m_driverService->isOpen(this)) {
        m_driverService->close(this);
    }
    
    KLOG(LOG_INFO, "Client terminated.")
    return IOUserClient::didTerminate(provider, options, defer);
}

#pragma mark Fetching memory and data queue notifications

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
        KLOG(LOG_ERROR, "A second client tried to connect.")
        return kIOReturnExclusiveAccess;
    }
    
    KLOG(LOG_INFO, "Client connected successfully.")
    return kIOReturnSuccess;
}

IOReturn DriverClient::setLogLevel(OSObject* target, void* reference, IOExternalMethodArguments* arguments) {
    DriverClient *me = OSDynamicCast(DriverClient, target);
    if (me == nullptr) {
        return kIOReturnBadArgument;
    }
    
    UInt32 level = (UInt32)arguments->scalarInput[0];
    if (g_logLevel != level) {
        KLOG(LOG_INFO, "Log level setted to be %d", level)
        g_logLevel = level;
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
        { &DriverClient::setLogLevel, 1, 0, 0, 0},
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
