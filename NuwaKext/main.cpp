//
//  main.cpp
//  NuwaKext
//
//  Created by ConradSun on 2022/7/13.
//

#include <IOKit/IOService.h>
#include <IOKit/IOUserClient.h>

/**
 * The macOS 10.15 SDK added these Dispatch methods but they aren't
 * available on older macOS versions and so prevent kext linking.
 * Defining them here as hidden weak no-op's fixes linking and seems to work.
**/
kern_return_t __attribute__((visibility("hidden"))) __attribute__((weak)) OSMetaClassBase::Dispatch(const IORPC rpc) { return KERN_SUCCESS; }
kern_return_t __attribute__((visibility("hidden"))) __attribute__((weak)) OSObject::Dispatch(const IORPC rpc) { return KERN_SUCCESS; }
kern_return_t __attribute__((visibility("hidden"))) __attribute__((weak)) IOService::Dispatch(const IORPC rpc) { return KERN_SUCCESS; }
kern_return_t __attribute__((visibility("hidden"))) __attribute__((weak)) IOUserClient::Dispatch(const IORPC rpc) { return KERN_SUCCESS; }
