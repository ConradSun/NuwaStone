//
//  EventDispatcher.cpp
//  NuwaKext
//
//  Created by 孙康 on 2022/7/12.
//

#include "EventDispatcher.hpp"
#include "KextLogger.hpp"

EventDispatcher* EventDispatcher::m_sharedInstance = nullptr;

bool EventDispatcher::init() {
    m_authDataQueue = IOSharedDataQueue::withEntries(kMaxAuthQueueEvents, sizeof(NuwaKextEvent));
    if (m_authDataQueue == nullptr) {
        Logger(LOG_ERROR, "Failed to create auth data queue.")
        return false;
    }
    m_notifyDataQueue = IOSharedDataQueue::withEntries(kMaxNotifyQueueEvents, sizeof(NuwaKextEvent));
    if (m_notifyDataQueue == nullptr) {
        Logger(LOG_ERROR, "Failed to create notify data queue.")
        m_authDataQueue->release();
        m_authDataQueue = nullptr;
        return false;
    }
    return true;
}

void EventDispatcher::free() {
    m_authDataQueue->setNotificationPort(nullptr);
    m_authDataQueue->release();
    m_authDataQueue = nullptr;
    m_notifyDataQueue->release();
    m_notifyDataQueue = nullptr;
}

EventDispatcher *EventDispatcher::getInstance() {
    if (m_sharedInstance != nullptr) {
        return m_sharedInstance;
    }
    
    m_sharedInstance = new EventDispatcher();
    if (!m_sharedInstance->init()) {
        Logger(LOG_ERROR, "Failed to create instance for EventDispatcher.")
        return nullptr;
    }
    return m_sharedInstance;
}

void EventDispatcher::release() {
    if (m_sharedInstance == nullptr) {
        return;
    }
    
    m_sharedInstance->free();
    delete m_sharedInstance;
    m_sharedInstance = nullptr;
}

void EventDispatcher::setNotificationPortForQueue(UInt32 type, mach_port_t port) {
    switch (type) {
        case kQueueTypeAuth:
            m_authDataQueue->setNotificationPort(port);
            break;
        case kQueueTypeNotify:
            m_notifyDataQueue->setNotificationPort(port);
            break;
        default:
            break;
    }
}

IOMemoryDescriptor *EventDispatcher::getMemoryDescriptorForQueue(UInt32 type) const {
    IOMemoryDescriptor *descriptor = nullptr;
    
    switch (type) {
        case kQueueTypeAuth:
            descriptor = m_authDataQueue->getMemoryDescriptor();
            break;
        case kQueueTypeNotify:
            descriptor = m_notifyDataQueue->getMemoryDescriptor();
            break;
        default:
            break;
    }
    return descriptor;
}

bool EventDispatcher::postToAuthQueue(NuwaKextEvent *eventInfo) {
    bool result = m_authDataQueue->enqueue(eventInfo, sizeof(NuwaKextEvent));
    if (!result) {
        Logger(LOG_WARN, "Failed to push back data to auth queue.")
    }
    return result;
}

bool EventDispatcher::postToNtifyQueue(NuwaKextEvent *eventInfo) {
    bool result = m_notifyDataQueue->enqueue(eventInfo, sizeof(NuwaKextEvent));
    if (!result) {
        Logger(LOG_WARN, "Failed to push back data to notify queue.")
    }
    return result;
}
