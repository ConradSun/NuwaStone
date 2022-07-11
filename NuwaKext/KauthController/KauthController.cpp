//
//  KauthController.cpp
//  NuwaKext
//
//  Created by 孙康 on 2022/7/10.
//

#include "KauthController.hpp"
#include "KextLog.h"

OSDefineMetaClassAndStructors(KauthController, OSObject);

bool KauthController::init() {
    if (!OSObject::init()) {
        return false;
    }
    
    return true;
}

void KauthController::free() {
    OSObject::free();
}

kern_return_t KauthController::startListeners() {
    m_vnodeListener = kauth_listen_scope(KAUTH_SCOPE_VNODE, vnode_scope_callback, reinterpret_cast<void *>(this));
    if (m_vnodeListener == NULL) {
        return KERN_FAILURE;
    }
    m_fileopListener = kauth_listen_scope(KAUTH_SCOPE_FILEOP, fileop_scope_callback, reinterpret_cast<void *>(this));
    if (m_fileopListener == NULL) {
        return KERN_FAILURE;
    }
    return KERN_SUCCESS;
}

kern_return_t KauthController::stopListeners() {
    if (m_vnodeListener != NULL) {
        kauth_unlisten_scope(m_vnodeListener);
    }
    if (m_fileopListener != NULL) {
        kauth_unlisten_scope(m_fileopListener);
    }
    return KERN_SUCCESS;
}

extern "C"
int vnode_scope_callback(kauth_cred_t credential, void *idata, kauth_action_t action,
                         uintptr_t arg0, uintptr_t arg1, uintptr_t arg2, uintptr_t arg3) {
    return KAUTH_RESULT_DEFER;
}

extern "C"
int fileop_scope_callback(kauth_cred_t credential, void *idata, kauth_action_t action,
                          uintptr_t arg0, uintptr_t arg1, uintptr_t arg2, uintptr_t arg3) {
    return KAUTH_RESULT_DEFER;
}
