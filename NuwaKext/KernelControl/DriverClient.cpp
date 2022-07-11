//
//  DriverClient.cpp
//  NuwaKext
//
//  Created by 孙康 on 2022/7/7.
//

#include "DriverClient.hpp"
#include "KextCommon.h"
#include "KextLog.h"

KextLogLevel logLevel = LOG_INFO;
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
    return IOUserClient::start(provider);
}

void DriverClient::stop(IOService *provider) {
    IOUserClient::stop(provider);
}

IOReturn DriverClient::clientDied() {
    KLOG(LOG_INFO, "Client died.")
    return terminate(0) ? kIOReturnSuccess : kIOReturnError;
}

IOReturn DriverClient::clientClose() {
    KLOG(LOG_INFO, "Client disconnected.")
    return terminate(0) ? kIOReturnSuccess : kIOReturnError;
}

bool DriverClient::didTerminate(IOService *provider, IOOptionBits options, bool *defer) {
    KLOG(LOG_INFO, "Client terminated.")
    return IOUserClient::didTerminate(provider, options, defer);
}

IOReturn DriverClient::open(OSObject *target, void *reference, IOExternalMethodArguments *arguments) {
    DriverClient *me = OSDynamicCast(DriverClient, target);
    
    if (!me) {
        return kIOReturnBadArgument;
    }
    if (me->isInactive()) {
        return kIOReturnNotAttached;
    }
    if (!me->myService->open(me)) {
        KLOG(LOG_ERROR, "A second client tried to connect.");
        return kIOReturnExclusiveAccess;
    }
    
    KLOG(LOG_INFO, "Client connected successfully.");
    return kIOReturnSuccess;
}

#pragma mark Method Resolution

IOReturn DriverClient::externalMethod(UInt32 selector, IOExternalMethodArguments *arguments,
                                      IOExternalMethodDispatch *dispatch, OSObject *target, void *reference) {
    // Array of methods callable by clients.
    static IOExternalMethodDispatch sMethods[kNuwaUserClientNMethods] = {
        // Function ptr, input scalar count, input struct size, output scalar count, output struct size
        { &DriverClient::open, 0, 0, 0, 0 },
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
