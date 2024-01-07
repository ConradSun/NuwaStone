//
//  DriverCache.hpp
//  NuwaKext
//
//  Created by ConradSun on 2022/7/14.
//

#ifndef DriverCache_hpp
#define DriverCache_hpp

#include <IOKit/IOLib.h>
#include <libkern/OSTypes.h>

extern lck_attr_t *g_driverLockAttr;
extern lck_grp_attr_t *g_driverLockGrpAttr;
extern lck_grp_t *g_driverLockGrp;

static const UInt8 kDefaultBucketCapacity = 4;

template <typename KeyType>

/**
 * @brief Calculate the hash value of the cache
 
 * @param key   key must be numeric type
 * @param count number of buckets
 * @return      hash value
 */
static UInt64 cacheHasher(KeyType const &key, UInt64 count) {
    // 11400714819323198549 is the largest 64-bit prime number. Use prime numbers to reduce hash collisions.
    UInt64 hash = (UInt64)key * 11400714819323198549UL;
    return hash % count;
};

template <typename KeyType, typename ValueType>
class DriverCache {

public:
    ValueType zero;
    
    DriverCache(UInt64 capacity = 1024) {
        if (capacity < 1) {
            capacity = 1;
        }
        m_capacity = capacity;
        m_itemCount = 0;
        // Make sure the number of buckets is even
        m_bucketCount = (((capacity + kDefaultBucketCapacity) / kDefaultBucketCapacity) >> 1) << 1;
        m_buckets = (Bucket *)IOMallocAligned(sizeof(Bucket)*m_bucketCount, 2);
        bzero(m_buckets, sizeof(Bucket)*m_bucketCount);
        m_lock = lck_mtx_alloc_init(g_driverLockGrp, g_driverLockAttr);
    }
    
    ~DriverCache() {
        clearObjects();
        if (m_lock != nullptr) {
            lck_mtx_free(m_lock, g_driverLockGrp);
        }
    }
    
    ValueType getObject(KeyType key) {
        ValueType value = zero;
        Bucket *bucket = &m_buckets[cacheHasher(key, m_bucketCount)];

        lck_mtx_lock(m_lock);
        Entry *entry = bucket->entry;
        while (entry != nullptr) {
            if (key == entry->key) {
                value = entry->value;
                break;
            }
            entry = entry->next;
        }
        lck_mtx_unlock(m_lock);

        return value;
    }
    
    bool setObject(const KeyType &key, const ValueType &value) {
        bool result = false;
        Bucket *bucket = &m_buckets[cacheHasher(key, m_bucketCount)];

        lck_mtx_lock(m_lock);
        Entry *last = nullptr;
        Entry *current = bucket->entry;

        while (current != nullptr) {
            if (key == current->key) {
                current->value = value;
                if (value == zero) {
                    if (last == nullptr) {
                        bucket->entry = current->next;
                    } else {
                        last->next = current->next;
                    }
                    IOFreeAligned(current, sizeof(Entry));
                    current = nullptr;
                    OSDecrementAtomic(&m_itemCount);
                }
                result = true;
                break;
            }
            last = current;
            current = current->next;
        }

        if (current == nullptr && value != zero) {
            result = addObject(bucket, last, key, value);
        }

        lck_mtx_unlock(m_lock);
        return result;
    }
    
    void clearObjects() {
        for (UInt64 i = 0; i < m_bucketCount; ++i) {
            lck_mtx_lock(m_lock);
            Entry *current = m_buckets[i].entry;
            Entry *next = nullptr;
            while (current != nullptr) {
                next = current->next;
                IOFreeAligned(current, sizeof(Entry));
                current = next;
            }
            lck_mtx_unlock(m_lock);
        }
        
        m_itemCount = 0;
        bzero(m_buckets, sizeof(Bucket)*m_bucketCount);
    }
    
private:
    struct Entry {
        KeyType key;
        ValueType value;
        Entry *next;
    };
    struct Bucket {
        Entry *entry;
    };
    
    bool addObject(Bucket *bucket, Entry *last, const KeyType &key, const ValueType &value) {
        if (m_itemCount >= m_capacity) {
            lck_mtx_unlock(m_lock);
            if (m_itemCount >= m_capacity) {
                clearObjects();
            }
            lck_mtx_lock(m_lock);
        }

        Entry *entry = (Entry *)IOMallocAligned(sizeof(Entry), 2);
        if (entry == nullptr) {
            return false;
        }
        entry->key = key;
        entry->value = value;
        entry->next = nullptr;
        
        if (bucket->entry == nullptr) {
            bucket->entry = entry;
        } else if (last != nullptr) {
            last->next = entry;
        } else {
            return false;
        }
        OSIncrementAtomic(&m_itemCount);
        return true;
    }
    
    UInt64 m_capacity;
    UInt64 m_itemCount;
    UInt64 m_bucketCount;
    Bucket *m_buckets;
    
    lck_mtx_t *m_lock;
};

#endif /* DriverCache_hpp */
