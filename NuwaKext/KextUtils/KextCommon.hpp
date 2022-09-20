//
//  KextCommon.hpp
//  NuwaStone
//
//  Created by ConradSun on 2022/7/11.
//

#ifndef KextCommon_h
#define KextCommon_h

#ifdef __cplusplus
extern "C" {
#endif

#include <netinet/in.h>
#include <libkern/OSTypes.h>

#ifdef __cplusplus
}
#endif

static const char *kSocketFilterName = "NuwaStone.socketfilter";
static const UInt32 kBaseFilterHandle = 0xFEEDBEEF;
static const UInt32 kMaxAuthWaitTime = 30000; // ms
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
    kNuwaUserClientUpdateMuteList,
    kNuwaUserClientNMethods
} NuwaKextMethods;

typedef enum {
    kQueueTypeAuth,
    kQueueTypeNotify
} NuwaKextQueue;

typedef enum {
    kActionNull         = 0,
    
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

typedef enum {
    kFilterFileEvent    = 0,
    kFilterNetEvent     = 1,
    kAllowExec          = 2,
    kDenyExec           = 3,
} NuwaKextMuteType;

typedef struct {
    NuwaKextMuteType type;
    UInt64 vnodeID;
    SInt16 forAdding;
} NuwaKextMuteInfo;

typedef struct {
    SInt32 pid;
    SInt32 ppid;
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
            SInt32 queryStatus;
            char domainName[kMaxNameLength];
            char queryResult[kMaxPathLength];
        } dnsQuery;
    };
} NuwaKextEvent;

#endif /* KextCommon_h */
