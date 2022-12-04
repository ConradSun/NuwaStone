//
//  ListManager.hpp
//  NuwaKext
//
//  Created by ConradSun on 2022/9/19.
//

#ifndef ListManager_hpp
#define ListManager_hpp

#include "DriverCache.hpp"
#include "KextCommon.hpp"

typedef enum {
    kProcPlainType  = 0,
    kProcWhiteType  = 1,
    kProcBlackType  = 2
} NuwaKextProcType;

class ListManager {

public:
    // Called when obtain the instance of the class.
    static ListManager *getInstance();
    
    // Called when release the instance of the class.
    static void release();
    
    // Called when add process to white/black list.
    bool updateAuthProcessList(UInt64 *vnodeID, NuwaKextMuteType type);
    
    // Called when add path to file filter list.
    bool updateFilterFileList(UInt64 *vnodeID, NuwaKextMuteType type);
    
    // Called when check whether the process path within white/black list.
    UInt8 obtainAuthProcessList(UInt64 vnodeID);
    
    // Called when check whether the file path within white list.
    UInt8 obtainFilterFileList(UInt64 vnodeID);
    
private:
    bool init();
    void free();
    
    static ListManager *m_sharedInstance;
    DriverCache<UInt64, UInt8> *m_allowProcList;
    DriverCache<UInt64, UInt8> *m_denyProcList;
    DriverCache<UInt64, UInt8> *m_muteFileList;
};

#endif /* ListManager_hpp */
