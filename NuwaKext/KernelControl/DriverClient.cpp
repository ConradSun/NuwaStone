//
//  DriverClient.cpp
//  NuwaKext
//
//  Created by 孙康 on 2022/7/7.
//

#include "DriverClient.hpp"
#include "KextLog.hpp"

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
