//
//  CacheManager.hpp
//  NuwaKext
//
//  Created by ConradSun on 2022/7/14.
//

#ifndef CacheManager_hpp
#define CacheManager_hpp

#include "DriverCache.hpp"

typedef enum {
    kProcPlainType  = 0,
    kProcWhiteType  = 1,
    kProcBlackType  = 2
} NuwaKextProcType;

class CacheManager {

public:
    // Called when obtain the instance of the class.
    static CacheManager *getInstance();
    
    // Called when release the instance of the class.
    static void release();
    
    // Called when update the cache for auth result.
    bool updateAuthResultCache(UInt64 vnodeID, UInt8 result);
    
    // Called when update the cache for auth exec event.
    bool updateAuthExecCache(UInt64 vnodeID, UInt64 value);
    
    // Called when update the cache for port bind event.
    bool updatePortBindCache(UInt16 port, UInt64 value);
    
    // Called when update the cache for outbound flow.
    bool updateDnsOutCache(UInt64 addr, UInt64 value);
    
    // Called when add process to white/black list.
    bool updateProcAuthList(UInt64 vnodeID, bool isWhite);
    
    // Called when obtain the result from auth result cache.
    UInt8 obtainAuthResultCache(UInt64 vnodeID);
    
    // Called when obtain the result from auth exec cache.
    UInt64 obtainAuthExecCache(UInt64 vnodeID);
    
    // Called when obtain the result from port bind cache.
    UInt64 obtainPortBindCache(UInt16 port);
    
    // Called when obtain the result outbound cache.
    UInt64 obtainDnsOutCache(UInt64 addr);
    
    // Called when check whether the process path within white/black list.
    UInt8 obtainProcAuthList(UInt64 vnodeID);
    
private:
    bool init();
    void free();
    
    static CacheManager *m_sharedInstance;
    DriverCache<UInt64, UInt8> *m_authResultCache;
    DriverCache<UInt64, UInt64> *m_authExecCache;
    DriverCache<UInt16, UInt64> *m_portBindCache;
    DriverCache<UInt64, UInt64> *m_dnsOutCache;
    DriverCache<UInt64, UInt8> *m_procAuthList;
};

#endif /* CacheManager_hpp */
