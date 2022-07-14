//
//  KauthController.hpp
//  NuwaKext
//
//  Created by 孙康 on 2022/7/10.
//

#ifndef KauthController_hpp
#define KauthController_hpp

#include "EventDispatcher.hpp"
#include <sys/vnode.h>
#include <sys/kauth.h>
#include <libkern/c++/OSContainers.h>

class KauthController : public OSObject {
    OSDeclareDefaultStructors(KauthController);

public:
    // Used for initialization after instantiation.
    bool init() override;

    // Called automatically when retain count drops to 0.
    void free() override;
    
    // Starts the kauth listeners.
    bool startListeners();

    // Stops the kauth listeners.
    void stopListeners();
    
    // Called when send event to client.
    bool postToAuthQueue(NuwaKextEvent *eventInfo);
    
    void increaseEventCount();
    void decreaseEventCount();
    
    int vnodeCallback(const kauth_cred_t cred, const vfs_context_t ctx, const vnode_t vp, int *errno);
    
    kern_return_t fillBasicInfo(NuwaKextEvent *eventInfo, const vfs_context_t ctx, const vnode_t vp);
    kern_return_t fillProcInfo(NuwaKextProc *ProctInfo, const vfs_context_t ctx);
    kern_return_t fillFileInfo(NuwaKextFile *FileInfo, const vfs_context_t ctx, const vnode_t vp);
    
private:
    kauth_listener_t m_vnodeListener;
    kauth_listener_t m_fileopListener;
    EventDispatcher *m_eventDispatcher;
    static SInt32 m_activeEventCount;
};

/**
  @brief The kauth callback function for the Vnode scope

  @param credential actor's credentials
  @param idata data that was passed when the listener was registered
  @param action action that was requested
  @param arg0 VFS context
  @param arg1 Vnode being operated on
  @param arg2 Parent Vnode. May be nullptr.
  @param arg3 Pointer to an errno-style error.
*/
extern "C" int vnode_scope_callback(kauth_cred_t credential, void *idata,
                                    kauth_action_t action, uintptr_t arg0,
                                    uintptr_t arg1, uintptr_t arg2,
                                    uintptr_t arg3);

/**
  @brief The kauth callback function for the FileOp scope

  @param credential actor's credentials
  @param idata data that was passed when the listener was registered
  @param action action that was requested
  @param arg0 depends on action, usually the vnode ref.
  @param arg1 depends on action.
  @param arg2 depends on action, usually 0.
  @param arg3 depends on action, usually 0.
*/
extern "C" int fileop_scope_callback(kauth_cred_t credential, void *idata,
                                     kauth_action_t action, uintptr_t arg0,
                                     uintptr_t arg1, uintptr_t arg2,
                                     uintptr_t arg3);

#endif /* KauthController_hpp */
