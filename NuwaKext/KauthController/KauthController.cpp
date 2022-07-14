//
//  KauthController.cpp
//  NuwaKext
//
//  Created by 孙康 on 2022/7/10.
//

#include "KauthController.hpp"
#include "EventDispatcher.hpp"
#include "KextLog.hpp"
#include <sys/proc.h>

OSDefineMetaClassAndStructors(KauthController, OSObject);
SInt32 KauthController::m_activeEventCount = 0;

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

bool KauthController::startListeners() {
    m_vnodeListener = kauth_listen_scope(KAUTH_SCOPE_VNODE, vnode_scope_callback, reinterpret_cast<void *>(this));
    if (m_vnodeListener == nullptr) {
        return false;
    }
    m_fileopListener = kauth_listen_scope(KAUTH_SCOPE_FILEOP, fileop_scope_callback, reinterpret_cast<void *>(this));
    if (m_fileopListener == nullptr) {
        return false;
    }
    return true;
}

void KauthController::stopListeners() {
    if (m_vnodeListener != nullptr) {
        kauth_unlisten_scope(m_vnodeListener);
    }
    if (m_fileopListener != nullptr) {
        kauth_unlisten_scope(m_fileopListener);
    }
}

bool KauthController::postToAuthQueue(NuwaKextEvent *eventInfo) {
    if (eventInfo == nullptr) {
        return false;
    }
    KLOG(Info, "pid: %d, path: %s.", eventInfo->mainProcess.pid, eventInfo->processCreate.path)
    return m_eventDispatcher->postToAuthQueue(eventInfo);
}

void KauthController::increaseEventCount() {
    OSIncrementAtomic(&m_activeEventCount);
}

void KauthController::decreaseEventCount() {
    OSDecrementAtomic(&m_activeEventCount);
}

int KauthController::vnodeCallback(const kauth_cred_t cred, const vfs_context_t ctx, const vnode_t vp, int *errno) {
    kern_return_t errCode = KERN_SUCCESS;
    NuwaKextEvent *event = (NuwaKextEvent *)IOMallocAligned(sizeof(NuwaKextEvent), 2);
    if (event == nullptr) {
        return KAUTH_RESULT_DEFER;
    }
    
    event->eventType = kActionAuthProcessCreate;
    errCode = fillBasicInfo(event, ctx, vp);
    if (errCode != KERN_SUCCESS) {
        KLOG(LOG_WARN, "Failed to fill basic info [%d].", errCode)
        return KAUTH_RESULT_DEFER;
    }
    errCode = fillProcInfo(&event->mainProcess, ctx);
    if (errCode != KERN_SUCCESS) {
        KLOG(LOG_WARN, "Failed to fill proc info [%d].", errCode)
        return KAUTH_RESULT_DEFER;
    }
    errCode = fillFileInfo(&event->processCreate, ctx, vp);
    if (errCode != KERN_SUCCESS) {
        KLOG(LOG_WARN, "Failed to fill file info [%d].", errCode)
        return KAUTH_RESULT_DEFER;
    }
    postToAuthQueue(event);
    IOFreeAligned(event, sizeof(NuwaKextEvent));
    
    return KAUTH_RESULT_DEFER;
}

kern_return_t KauthController::fillBasicInfo(NuwaKextEvent *eventInfo, const vfs_context_t ctx, const vnode_t vp) {
    kern_return_t errCode = KERN_SUCCESS;
    struct timeval time;
    struct vnode_attr vap;
    
    microtime(&time);
    eventInfo->eventTime = time.tv_sec;
    if (vp == nullptr) {
        return errCode;
    }
    
    VATTR_INIT(&vap);
    VATTR_WANTED(&vap, va_fsid);
    VATTR_WANTED(&vap, va_fileid);
    errCode = vnode_getattr(vp, &vap, ctx);
    if (errCode == KERN_SUCCESS) {
        eventInfo->vnodeID = ((UInt64)vap.va_fsid << 32) | vap.va_fileid;
    }
    
    return errCode;
}

kern_return_t KauthController::fillProcInfo(NuwaKextProc *ProctInfo, const vfs_context_t ctx) {
    if (ctx == nullptr) {
        return EINVAL;
    }
    
    proc_t proc = vfs_context_proc(ctx);
    kauth_cred_t cred = vfs_context_ucred(ctx);
    
    if (proc != NULL) {
        ProctInfo->pid = proc_pid(proc);
        ProctInfo->ppid = proc_ppid(proc);
    }
    
    if (cred != NULL) {
        ProctInfo->euid = kauth_cred_getuid(cred);
        ProctInfo->ruid = kauth_cred_getruid(cred);
        ProctInfo->egid = kauth_cred_getgid(cred);
        ProctInfo->rgid = kauth_cred_getrgid(cred);
    }
    
    return KERN_SUCCESS;
}

kern_return_t KauthController::fillFileInfo(NuwaKextFile *FileInfo, const vfs_context_t ctx, const vnode_t vp) {
    kern_return_t errCode = KERN_SUCCESS;
    int length = kMaxPathLength;
    struct vnode_attr vap;
    
    VATTR_INIT(&vap);
    VATTR_WANTED(&vap, va_uid);
    VATTR_WANTED(&vap, va_gid);
    VATTR_WANTED(&vap, va_mode);
    VATTR_WANTED(&vap, va_access_time);
    VATTR_WANTED(&vap, va_modify_time);
    VATTR_WANTED(&vap, va_change_time);
    errCode = vnode_getattr(vp, &vap, ctx);
    
    if (errCode == KERN_SUCCESS) {
        FileInfo->uid = vap.va_uid;
        FileInfo->gid = vap.va_gid;
        FileInfo->mode = vap.va_mode;
        FileInfo->atime = vap.va_access_time.tv_sec;
        FileInfo->mtime = vap.va_modify_time.tv_sec;
        FileInfo->ctime = vap.va_change_time.tv_sec;
        errCode = vn_getpath(vp, FileInfo->path, &length);
    }
    
    return errCode;
}

extern "C"
int vnode_scope_callback(kauth_cred_t credential, void *idata, kauth_action_t action,
                         uintptr_t arg0, uintptr_t arg1, uintptr_t arg2, uintptr_t arg3) {
    int response = KAUTH_RESULT_DEFER;
    vfs_context_t context = reinterpret_cast<vfs_context_t>(arg0);
    vnode_t vp = reinterpret_cast<vnode_t>(arg1);
    int *errno = reinterpret_cast<int *>(arg3);
    KauthController *selfPtr = OSDynamicCast(KauthController, reinterpret_cast<OSObject *>(idata));
    
    if (selfPtr == nullptr) {
        return response;
    }
    if (vnode_vtype(vp) != VREG) {
        return response;
    }
    if (action == KAUTH_VNODE_EXECUTE) {
        selfPtr->increaseEventCount();
        response = selfPtr->vnodeCallback(credential, context, vp, errno);
        selfPtr->decreaseEventCount();
    }
    
    return response;
}

extern "C"
int fileop_scope_callback(kauth_cred_t credential, void *idata, kauth_action_t action,
                          uintptr_t arg0, uintptr_t arg1, uintptr_t arg2, uintptr_t arg3) {
    return KAUTH_RESULT_DEFER;
}
