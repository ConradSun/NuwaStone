//
//  KauthController.hpp
//  NuwaKext
//
//  Created by 孙康 on 2022/7/10.
//

#ifndef KauthController_hpp
#define KauthController_hpp

#include <IOKit/IOLib.h>
#include <IOKit/IODataQueueShared.h>
#include <IOKit/IOMemoryDescriptor.h>
#include <IOKit/IOSharedDataQueue.h>
#include <sys/kauth.h>
#include <sys/proc.h>
#include <sys/vnode.h>

class KauthController : public OSObject {
    OSDeclareDefaultStructors(KauthController);

public:
    // Used for initialization after instantiation.
    bool init() override;

    // Called automatically when retain count drops to 0.
    void free() override;
    
    // Starts the kauth listeners.
    kern_return_t startListeners();

    // Stops the kauth listeners.
    kern_return_t stopListeners();
    
private:
    kauth_listener_t m_vnodeListener;
    kauth_listener_t m_fileopListener;
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
