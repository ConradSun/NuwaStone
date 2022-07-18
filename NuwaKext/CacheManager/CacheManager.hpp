//
//  CacheManager.hpp
//  NuwaKext
//
//  Created by 孙康 on 2022/7/14.
//

#ifndef CacheManager_hpp
#define CacheManager_hpp

#include "DriverCache.hpp"

class CacheManager {

public:
    // Called when obtain the instance of the class.
    static CacheManager *getInstance();
    
    // Called when release the instance of the class.
    static void release();
    
    // Called when update the cache for auth result.
    bool setForAuthResultCache(UInt64 vnodeID, UInt8 result);
    
    // Called when update the cache for auth exec event.
    bool setForAuthExecCache(UInt64 vnodeID, UInt64 value);
    
    // Called when obtain the result from auth result cache.
    UInt8 getFromAuthResultCache(UInt64 vnodeID);
    
    // Called when obtain the result from auth exec cache.
    UInt64 getFromAuthExecCache(UInt64 vnodeID);
    
private:
    bool init();
    void free();
    static CacheManager *m_sharedInstance;
    DriverCache<UInt64, UInt8> *m_authResultCache;
    DriverCache<UInt64, UInt64> *m_authExecCache;
};

#endif /* CacheManager_hpp */
