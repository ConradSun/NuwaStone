//
//  KextCommon.hpp
//  NuwaStone
//
//  Created by ConradSun on 2022/7/11.
//

#ifndef KextCommon_h
#define KextCommon_h

#include <libkern/OSTypes.h>
#include <netinet/in.h>

static const char *kDriverIdentifier = "com.nuwastone.kext";
static const char *kDriverService = "DriverService";
static const char *kDriverPath = "/Applications/NuwaClient.app/Contents/PlugIns/NuwaStone.kext";
static const char *kSocketFilterName = "NuwaStone.socketfilter";
static const UInt32 kBaseFilterHandle = 0xFEEDBEEF;
static const UInt32 kMaxAuthWaitTime = 100; // ms
static const UInt32 kMaxAuthQueueEvents = 1024;
static const UInt32 kMaxNotifyQueueEvents = 2048;
static const UInt32 kMaxCacheItems = 1024;
static const UInt32 kMaxPathLength = 1024;
static const UInt32 kMaxNameLength = 256;

typedef enum {
    kNuwaUserClientOpen,
    kNuwaUserClientAllowBinary,
    kNuwaUserClientDenyBinary,
    kNuwaUserClientSetLogLevel,
    kNuwaUserClientNMethods
} NuwaKextMethods;

typedef enum {
    kQueueTypeAuth,
    kQueueTypeNotify
} NuwaKextQueue;

typedef enum {
    kActionAuthNull     = 0,
    
    kActionAuthBegin    = 0x100,
    kActionAuthProcessCreate,
    
    kActionNotifyBegin  = 0x200,
    kActionNotifyProcessCreate,
    kActionNotifyFileCloseModify,
    kActionNotifyFileRename,
    kActionNotifyFileDelete,
    kActionNotifyNetworkAccess,
    kActionNotifyDnsQuery
} NuwaKextAction;

typedef struct {
    UInt32 pid;
    UInt32 ppid;
    UInt32 ruid;
    UInt32 euid;
    UInt32 rgid;
    UInt32 egid;
} NuwaKextProc;

typedef struct {
    UInt32 uid;
    UInt32 gid;
    UInt16 mode;
    UInt64 atime;
    UInt64 mtime;
    UInt64 ctime;
    char path[kMaxPathLength];
} NuwaKextFile;

typedef struct {
    UInt64 vnodeID;
    UInt64 eventTime;
    NuwaKextAction eventType;
    NuwaKextProc mainProcess;

    union {
        NuwaKextFile fileDelete;
        NuwaKextFile fileCloseModify;
        NuwaKextFile processCreate;
        struct {
            NuwaKextFile srcFile;
            char newPath[kMaxPathLength];
        } fileRename;
        struct {
            UInt16 protocol;
            struct sockaddr localAddr;
            struct sockaddr remoteAddr;
        } netAccess;
        struct {
            SInt queryStatus;
            char domainName[kMaxNameLength];
            char queryResult[kMaxPathLength];
        } dnsQuery;
    };
} NuwaKextEvent;

#endif /* KextCommon_h */
