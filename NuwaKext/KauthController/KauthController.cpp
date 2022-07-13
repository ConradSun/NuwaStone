//
//  KauthController.cpp
//  NuwaKext
//
//  Created by 孙康 on 2022/7/10.
//

#include "KauthController.hpp"
#include "EventDispatcher.hpp"
#include "KextLog.hpp"

OSDefineMetaClassAndStructors(KauthController, OSObject);

bool KauthController::init() {
    if (!OSObject::init()) {
        return false;
    }
    
    m_eventDispatcher = EventDispatcher::getInstance();
    if (m_eventDispatcher == nullptr) {
        return false;
    }
    return true;
}

void KauthController::free() {
    m_eventDispatcher = nullptr;
    OSObject::free();
}

kern_return_t KauthController::startListeners() {
    m_vnodeListener = kauth_listen_scope(KAUTH_SCOPE_VNODE, vnode_scope_callback, reinterpret_cast<void *>(this));
    if (m_vnodeListener == nullptr) {
        return KERN_FAILURE;
    }
    m_fileopListener = kauth_listen_scope(KAUTH_SCOPE_FILEOP, fileop_scope_callback, reinterpret_cast<void *>(this));
    if (m_fileopListener == nullptr) {
        return KERN_FAILURE;
    }
    return KERN_SUCCESS;
}

kern_return_t KauthController::stopListeners() {
    if (m_vnodeListener != nullptr) {
        kauth_unlisten_scope(m_vnodeListener);
    }
    if (m_fileopListener != nullptr) {
        kauth_unlisten_scope(m_fileopListener);
    }
    return KERN_SUCCESS;
}

bool KauthController::postToAuthQueue(NuwaKextEvent *eventInfo) {
    if (eventInfo == nullptr) {
        return false;
    }
    return m_eventDispatcher->postToAuthQueue(eventInfo);
}

extern "C"
int vnode_scope_callback(kauth_cred_t credential, void *idata, kauth_action_t action,
                         uintptr_t arg0, uintptr_t arg1, uintptr_t arg2, uintptr_t arg3) {
    KauthController *selfPtr = OSDynamicCast(KauthController, reinterpret_cast<OSObject *>(idata));
    if (selfPtr == nullptr) {
        return KAUTH_RESULT_DEFER;
    }
    
    NuwaKextEvent event = {0};
    selfPtr->postToAuthQueue(&event);
    return KAUTH_RESULT_DEFER;
}

extern "C"
int fileop_scope_callback(kauth_cred_t credential, void *idata, kauth_action_t action,
                          uintptr_t arg0, uintptr_t arg1, uintptr_t arg2, uintptr_t arg3) {
    return KAUTH_RESULT_DEFER;
}
