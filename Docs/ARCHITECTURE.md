# NuwaStone Architecture Design

## Overview

NuwaStone is a modular, multi-process system for monitoring and auditing file, process, and network events on macOS. The architecture provides clear separation of concerns, security boundaries, and supports both legacy (macOS 10.x) and modern (macOS 11.x+) system extension mechanisms.

## Table of Contents

- [System Architecture](#system-architecture)
- [Component Communication](#component-communication)
- [Extension Compatibility](#extension-compatibility)
- [Component Details](#component-details)

## System Architecture

### High-Level Architecture

```
┌───────────────────────────────────────────┐
│                 macOS System              │
├───────────────────────────────────────────┤
│  ┌─────────────────────────────────────┐  │
│  │      NuwaClient (User App)          │  │
│  │   ┌─────────────────────────────┐   │  │
│  │   │    ViewController (UI)      │   │  │
│  │   └─────────────────────────────┘   │  │
│  │   ProcessCache (Meta Cache)         │  │
│  └─────────────────────────────────────┘  │
└───────────────────────────────────────────┘
                    │ XPC
                    ▼
┌───────────────────────────────────────────┐
│           NuwaService (Privileged)        │
├───────────────────────────────────────────┤
│  ┌─────────────────────────────────────┐  │
│  │  KextManager   (macOS 10.x)         │  │
│  │  SextManager  (macOS 11.x+)         │  │
│  └─────────────────────────────────────┘  │
└───────────────────────────────────────────┘
                    │
                    │ Mach / XPC
                    ▼
┌───────────────┬─────────────┬─────────────┐
│    NuwaKext   │   NuwaSext  │   NuwaUtils │
│      Kauth    │      ES     │             │
│ Socket Filter │ Network Ext │             │
└───────────────┴─────────────┴─────────────┘
```

| Layer | Components | Purpose |
|-------|-----------|---------|
| **User Interface** | NuwaClient | Event display, user preferences |
| **Service** | NuwaService | Bridge to extensions, privileged ops |
| **Extension (Legacy)** | NuwaKext | Kernel-level monitoring (macOS 10.x) |
| **Extension (Modern)** | NuwaSext | User-level monitoring (macOS 11.x+) |
| **Shared** | NuwaUtils | Common data structures, protocols |

---

## Extension Compatibility

### Dual Extension Architecture

```
┌────────────────────────────────────────┐
│              NuwaStone                 │
├────────────────────────────────────────┤
│                                        │
│  ┌────────────────┬─────────────────┐  │
│  │   macOS 10.x   │  macOS 11.x+    │  │
│  └───────┬────────┴────────┬────────┘  │
│          ▼                 ▼           │
│  ┌───────────────┐  ┌───────────────┐  │
│  │   NuwaKext    │  │   NuwaSext    │  │
│  │  Kauth/Auth   │  │   ES Auth     │  │
│  │ SocketFilter  │  │ Network Ext   │  │
│  └───────────────┘  └───────────────┘  │
└────────────────────────────────────────┘
```

### Feature Parity

| Feature | Kext (10.x) | Sext (11.x+) |
|---------|----------------|------------------|
| File Events | ✓ Kauth Vnode | ✓ ES NOTIFY |
| Process Execution | ✓ Kauth Vnode | ✓ ES AUTH |
| Process Exit | ✗ | ✓ ES NOTIFY |
| Network Connect | ✓ SocketFilter | ✓ NE Proxy |
| DNS Query | ✓ SocketFilter | ✓ NE Proxy |
| Authorization | ✓ Kauth | ✓ ES AUTH |

---

## Component Details

### NuwaClient (User Interface)

**Purpose:** Main application for event monitoring and management

| Component | Description |
|----------|-------------|
| `ViewController` | Main event display, filtering, and graph visualization |
| `GraphView` | Real-time event rate display with line charts |
| `PrefsViewController` | System info display and preference settings |
| `AlertWindowController` | Authorization alerts for process execution |
| `EventCache` | Process metadata caching and periodic cleanup |

**Communication:** XPC Client to NuwaService

### NuwaService (Privileged Daemon)

**Purpose:** Bridge between UI and system extensions

| Component | Description |
|----------|-------------|
| `XPCConnection` | XPC server management, connections from UI |
| `KextControl` | Kernel extension control (load/unload) |
| `SextControl` | System extension control (start/stop) |

**Communications:** XPC Server to NuwaClient, Mach ports to NuwaKext, XPC to NuwaSext

### NuwaKext (Kernel Extension)

**Purpose:** Kernel-level event monitoring for macOS 10.x

| Component | Description |
|----------|-------------|
| `KauthController` | File/Process operation interception |
| `SocketFilter` | Network connection and DNS filtering |
| `EventDispatcher` | Event queue management (IOSharedDataQueue) |
| `KernelControl` | IOUserClient implementation, shared memory |
| `CacheManager` | Authorization result caching |
| `ListManager` | Allow/deny list management |

**Communication:** Shared memory via IOKit, Mach ports for notification

### NuwaSext (System Extension)

**Purpose:** User-level event monitoring for macOS 11.x+

| Component | Description |
|----------|-------------|
| `ClientManager` | Endpoint Security client, event subscription |
| `ContentFilter` | Network Extension implementation |
| `XPCServer` | XPC server for daemon communication |
| `ResponseManager` | Pending auth event tracking |
| `ListManager` | Mute list management |

**Communication:** XPC to NuwaService, Network Endpoint Security extension

### NuwaUtils (Shared Components)

**Purpose:** Common code and data structures

| Component | Description |
|----------|-------------|
| `NuwaEvent` | Event data structures and enumerations |
| `NuwaCommon` | Shared constants, utilities |
| `NuwaLogger` | Logging system with multiple levels |
| `NuwaBridge.hpp` | C++/Swift interoperability headers |

---

## Security Model

### Privilege Separation

```
┌────────────────────────────────────────┐
│                User Space              │
├────────────────────────────────────────┤
│        NuwaClient (Unprivileged)       │
│         x No direct system access      │
└────────────────────────────────────────┘
                    │
                    ▼ XPC
┌────────────────────────────────────────┐
│       NuwaService (Privileged)         │
├────────────────────────────────────────┤
│               ✓ XPC Server             │
│        ✓ System Resource Access        │
│        ✓ Privileged Operations         │
└────────────────────────────────────────┘
                    │ Mach / XPC
                    ▼
┌───────────────────┬────────────────────┐
│     NuwaKext      │      NuwaSext      │
│  ✓ Deep System    │   ✓ Deep System    │
│     Access        │      Access        │
└───────────────────┴────────────────────┘
```

### Entitlements

**NuwaClient:** `com.apple.security.application-groups`, `com.apple.security.automation.apple-events`

**NuwaService:** `com.apple.security.get-task-allow`, `com.apple.security.exception.files.absolute-path._usr_bin_ps`

**NuwaKext:** `com.apple.security.cs.kext`

**NuwaSext:** `com.apple.developer.system-extension.network`, `com.apple.developer.system-extension.endpoint-security`

---

## Extension Lifecycle

### Kernel Extension (Kext)

```
Installation → kextload
                ↓
IOService Start → KauthController Listeners → SocketFilter Register
                ↓
Ready → Event Monitoring Loop
                ↓
kextunload → Listeners Stop → SocketFilter Unregister → IOService Stop → Unload
```

### System Extension (Sext)

```
Installation → systemextensionsctl install
                ↓
User Approval (Privacy & Security)
                ↓
startSystemExtensionMode() → ES Client Created → Event Subscriptions
                ↓
Ready → Event Monitoring Loop
                ↓
systemextensionsctl uninstall → stopMonitoring() → Client Deleted → Unload
```

---

## Summary

NuwaStone's architecture demonstrates:

✅ **Modulary**: Clear component separation with defined interfaces
✅ **Security**: Proper privilege boundaries and entitlements
✅ **Compatibility**: Supports macOS 10.x above with dual architecture
✅ **Performance**: Caching, concurrency optimizations, and batch processing
✅ **Maintainability**: Protocols, shared utilities, and consistent naming
✅ **Extensibility**: Easy to add new event types and filters
✅ **Reliability**: Error handling, timeout mechanisms, and graceful degradation

The dual extension architecture (Kext + Sext) ensures coverage across macOS versions while modernizing for future macOS releases.
