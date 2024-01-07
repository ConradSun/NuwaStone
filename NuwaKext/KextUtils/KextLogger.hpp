//
//  KextLogger.hpp
//  NuwaKext
//
//  Created by ConradSun on 2022/7/7.
//

#ifndef KextLogger_h
#define KextLogger_h

#include <IOKit/IOLib.h>

/**
* @berif Log level for NuwaKext
*/
typedef enum {
    LOG_OFF     = 1,
    LOG_ERROR   = 2,
    LOG_WARN    = 3,
    LOG_INFO    = 4,
    LOG_DEBUG   = 5
} KextLogLevel;

extern UInt32 g_logLevel;

#define Logger(level, format, ...) \
    if (g_logLevel >= level) { \
        IOLog("%s %s:%d [-] " format "\n", \
        #level, __func__, __LINE__, ##__VA_ARGS__); \
    } \

#endif /* KextLogger_h */
