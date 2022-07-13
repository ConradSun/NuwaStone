//
//  KextLog.hpp
//  NuwaKext
//
//  Created by 孙康 on 2022/7/7.
//

#ifndef KextLog_h
#define KextLog_h

#include <IOKit/IOLib.h>

typedef enum {
    LOG_OFF     = 1,
    LOG_ERROR   = 2,
    LOG_WARN    = 3,
    LOG_INFO    = 4,
    LOG_DEBUG   = 5
} KextLogLevel;

extern UInt32 g_logLevel;

#define KLOG(level, format, ...) \
    if (g_logLevel >= level) { \
        IOLog("%s %s:%d [-] " format "\n", \
        #level, __func__, __LINE__, ##__VA_ARGS__); \
    } \

#endif /* KextLog_h */
