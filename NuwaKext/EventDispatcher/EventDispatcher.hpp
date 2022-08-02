//
//  EventDispatcher.hpp
//  NuwaKext
//
//  Created by ConradSun on 2022/7/12.
//

#ifndef EventDispatcher_hpp
#define EventDispatcher_hpp

#include <IOKit/IODataQueueShared.h>
#include <IOKit/IOMemoryDescriptor.h>
#include <IOKit/IOSharedDataQueue.h>
#include "KextCommon.hpp"

class EventDispatcher {

public:
    // Called when obtain the instance of the class.
    static EventDispatcher *getInstance();
    
    // Called when release the instance of the class.
    static void release();
    
    // Sets the Mach port for notifying the auth or other queue.
    void setNotificationPortForQueue(UInt32 type, mach_port_t port);
    
    // Called in client to provide the shared dataqueue memory for the auth or other queue.
    IOMemoryDescriptor *getMemoryDescriptorForQueue(UInt32 type) const;
    
    // Called when send auth event to client.
    bool postToAuthQueue(NuwaKextEvent *eventInfo);
    
    // Called when send notify event to client.
    bool postToNotifyQueue(NuwaKextEvent *eventInfo);
    
private:
    bool init();
    void free();
    static EventDispatcher *m_sharedInstance;
    IOSharedDataQueue *m_authDataQueue;
    IOSharedDataQueue *m_notifyDataQueue;
};

#endif /* EventDispatcher_hpp */
