# NuwaStone API Documentation

## Table of Contents

- [System Architecture](#system-architecture)
- [Core Protocols](#core-protocols)
- [Data Types](#data-types)
- [Usage Examples](#usage-examples)

---

## System Architecture

NuwaStone uses a modular three-layer architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                     NuwaStone Architecture                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌───────────────────────┐   ┌───────────────────────────┐  │
│  │   NuwaClient          │   │   NuwaService             │  │
│  │   (User Interface)    │──▶│   (Bridge/Privileged)     │  │
│  │   Events Display      │XPC│   Extension Control       │  │
│  │   User Preferences    │   │   System Resources        │  │
│  └───────────┬───────────┘   └───────────┬───────────────┘  │
│              │ Mach / XPC                │ Mach / XPC       │
│              ▼                           ▼                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌───────────────────────┐  ┌───────────────────────────┐   │
│  │   NuwaKext            │  │   NuwaSext                │   │
│  │   (macOS 10.x)        │  │   (macOS 11.x+)           │   │
│  │   Kernel Monitoring   │  │   User-space Monitoring   │   │
│  │   Kauth + Socket      │  │   ES + Network            │   │
│  └───────────────────────┘  └───────────────────────────┘   │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│              NuwaUtils (Shared Code Library)                │
│    Common Data Structures • Protocols • Logging             │
└─────────────────────────────────────────────────────────────┘
```

| Layer | Components | Purpose |
|-------|-----------|---------|
| User Interface | NuwaClient | Event display, user preferences |
| Service | NuwaService | Bridge to extensions, privileged operations |
| Extensions | NuwaKext, NuwaSext | Kernel/System monitoring |
| Shared | NuwaUtils | Common code, data structures |

---

## Core Protocols

### NuwaEventProviderProtocol

Event provider interface for Kernel Extension and System Extension.

```swift
protocol NuwaEventProviderProtocol {
    var processDelegate: NuwaEventProcessProtocol? { get set }
    var isExtConnected: Bool { get }
    func startProvider() -> Bool
    func stopProvider() -> Bool
    func setLogLevel(level: NuwaLogLevel) -> Bool
    func replyAuthEvent(eventID: UInt64, isAllowed: Bool) -> Bool
    func udpateMuteList(list: [String], type: NuwaMuteType) -> Bool
}
```

**Returns:** `true` on success, `false` on failure.

### NuwaEventProcessProtocol

Event processing callbacks for the client application.

```swift
protocol NuwaEventProcessProtocol {
    func displayNotifyEvent(_ event: NuwaEventInfo)
    func processAuthEvent(_ event: NuwaEventInfo)
    func handleBrokenConnection()
}
```

---

## Data Types

### Event Types

| Type | Description |
|-------|-------------|
| `FileOpen` | File opened for reading |
| `FileCreate` | File created |
| `FileDelete` | File deleted |
| `FileCloseModify` | File closed after modification |
| `FileRename` | File renamed or moved |
| `ProcessCreate` | Process executed (macOS 11.x+) |
| `ProcessExit` | Process terminated (macOS 11.x+) |
| `NetAccess` | Network connection established |
| `DNSQuery` | DNS query performed |

### NuwaEventInfo Properties

| Property | Type | Description |
|----------|------|-------------|
| `eventID` | `UInt64` | Unique event identifier |
| `eventType` | `NuwaEventType` | Type of event |
| `eventTime` | `UInt64` | Unix timestamp |
| `pid` | `Int32` | Process ID |
| `ppid` | `Int32` | Parent process ID |
| `user` | `String` | Username of process owner |
| `procPath` | `String` | Executable path |
| `procArgs` | `[String]` | Process arguments |
| `props` | `[String: String]` | Event properties (bundle ID, code sign, etc.) |

---

## Usage Examples

### Starting Event Collection

```swift
override func viewDidLoad() {
    super.viewDidLoad()
    
    // Select provider based on macOS version
    if #available(macOS 11.0, *) {
        eventProvider = SextManager.shared
    } else {
        eventProvider = KextManager.shared
    }
    
    eventProvider?.processDelegate = self
    establishConnection()
}

@IBAction func controlButtonClicked(_ sender: NSButton) {
    guard let provider = eventProvider else { return }
    
    if provider.startProvider() {
        initMutePaths()
        setupDisplayTimer()
        isStarted = true
        updateUIState()
    }
}
```

### XPC Communication

```swift
class XPCConnection: NSObject {
    func connectToDaemon(delegate: ClientXPCProtocol, 
                     handler: @escaping (Bool) -> Void) {
        let newConnection = NSXPCConnection(machServiceName: DaemonBundle)
        newConnection.exportedObject = delegate
        let daemonInterface = NSXPCInterface(with: DaemonXPCProtocol.self)
        newConnection.remoteObjectInterface = daemonInterface
        
        newConnection.invalidationHandler = { [weak self] in
            self.connection = nil
            self.clientDelegate?.connectionDidInvalidate()
            handler(false)
        }
        
        connection = newConnection
        newConnection.resume()
        
        let proxy = newConnection.remoteObjectProxyWithErrorHandler { [weak self] error in
            Logger(.Error, "Connection failed: \(error)")
            self.connection?.invalidate()
            handler(false)
        } as? DaemonXPCProtocol
        
        proxy?.connectResponse(handler)
    }
}
```

---

## Constants Reference

| Constant | Value | Description |
|----------|--------|-------------|
| `DaemonBundle` | `com.nuwastone.service` | Daemon bundle ID |
| `ClientBundle` | `com.nuwastone.client` | Client bundle ID |
| `MaxAuthWaitTime` | `30000` | Authorization timeout (ms) |
| `MaxSignWaitTime` | `3000` | Code sign timeout (ms) |

## Error Types

| Error | Description |
|-------|-------------|
| `Success` | Operation successful |
| `MissingEntitlements` | Missing required entitlements |
| `PermissionDenied` | User denied permission |
| `ConnectionError` | Connection failure |
| `TimeoutError` | Operation timeout |

---

## Version Compatibility

| macOS Version | Extension Type | Events |
|---------------|----------------|--------|
| 10.13 - 10.15 | Kext | File, Process, Network |
| 11.0+ | Sext | File, Process, Network |

---

## Thread Safety

| Component | Queue | Purpose |
|-----------|-------|---------|
| ProcessCache | Concurrent | Process info storage |
| EventView | Concurrent | Event list management |

**Pattern:** Sync reads, barrier writes for cache.
