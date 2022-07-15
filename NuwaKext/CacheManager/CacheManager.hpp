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
    
    bool setObjectForAuthCache(UInt64 vnodeID, UInt8 result);
    UInt8 getObjectForAuthCache(UInt64 vnodeID);
    
private:
    bool init();
    void free();
    static CacheManager *m_sharedInstance;
    DriverCache<UInt64, UInt8> *m_authCache;
};

#endif /* CacheManager_hpp */
