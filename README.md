# NuwaStone
<p align="center">
    <div align="center"><img src=https://raw.githubusercontent.com/ConradSun/NuwaStone/main/Docs/nuwa.png width=138  /></div>
    <h2 align="center">NuwaStone</h2>
    <div align="center">A macOS behavior audit system with scope of files, processes and network events.</div>
</p>

<p align="center"><img src="https://raw.githubusercontent.com/ConradSun/NuwaStone/main/Docs/NuwaStone.png"></p>

It supports events as below
- File: create, delete, close with modified, rename
- Process: create, exit (only os11.x+)
- Network: connect, dns query

## Documentation
NuwaStone supports macOS10.12+ with Kernel Extension (for os10.x) and System Extension (for os11.x+).
The kext uses Kauth & SocketFilter for event collection and behavior auditing.
The sext uses Endpoint Security & Network Extension for event collection and behavior auditing.

## Installation
>1. Build 'NuwaClient' target in Xcode proejct
>2. Copy it to the 'Scripts' folder
>3. Run 'Scripts/install.sh' in Terminal

## Uninstallation
>1. Run 'Scripts/uninstall.sh' in Terminal

## Attention
NuwaStone wont't let unsigned app run without your authorization, but the app will run just this time if you do not authorize within 30 seconds.