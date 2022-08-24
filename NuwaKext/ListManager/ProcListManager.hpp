//
//  ProcListManager.hpp
//  NuwaKext
//
//  Created by ConradSun on 2022/8/22.
//

#ifndef ProcListManager_hpp
#define ProcListManager_hpp

#include "DriverCache.hpp"

typedef enum {
    kProcPlainType  = 0,
    kProcWhiteType  = 1,
    kProcBlackType  = 2
} NuwaKextProcType;

class ProcListManager {
    
public:
    // Called when obtain the instance of the class.
    static ProcListManager *getInstance();
    
    // Called when release the instance of the class.
    static void release();
    
    // Called when add process to white/black list.
    bool addProcess(UInt64 vnodeID, bool isWhite);
    
    // Called when check whether the process path within white/black list.
    NuwaKextProcType containProcess(UInt64 vnodeID);
    
private:
    bool init();
    void free();
    
    static ProcListManager *m_sharedInstance;
    DriverCache<UInt64, UInt8> *m_procList;
};

#endif /* ProcListManager_hpp */
