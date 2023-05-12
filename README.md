# NuwaStone

<p align="center">
    <div align="center"><img src=https://raw.githubusercontent.com/ConradSun/NuwaStone/main/Docs/nuwa.png width=138  /></div>
    <h2 align="center">NuwaStone</h2>
    <div align="center">A macOS behavior audit system with scope of file, process and network events.</div>
</p>

<p align="center"><img src="https://raw.githubusercontent.com/ConradSun/NuwaStone/main/Docs/NuwaStone.png"></p>

[![LICENSE](https://img.shields.io/badge/license-GPL--3.0-green)](https://github.com/ConradSun/NuwaStone/blob/main/LICENSE) [![Language](https://img.shields.io/badge/Language-swift-red.svg)](https://www.swift.org)

It supports events as below

- File: create, delete, close with modified, rename
- Process: create, exit (only os11.x+)
- Network: connect, dns query

## Documentation

NuwaStone supports macOS10.13+ with Kernel Extension (for os10.x) and System Extension (for os11.x+).
The kext uses Kauth & SocketFilter for event collection and behavior auditing.
The sext uses Endpoint Security & Network Extension for event collection and behavior auditing.

## Installation

> 1.  Disable SIP by following [here](https://developer.apple.com/documentation/security/disabling_and_enabling_system_integrity_protection).
> 2.  Download the installation package [here](https://github.com/ConradSun/NuwaStone/releases).
> 3.  Then double-click _NuwaStone-vxx.pkg_ to follow the guide.
> 4.  Close the installation guide.

## Uninstallation

> 1.  Select 'Uninstall NuwaStone' from the status bar menu of **NuwaClient** application.

## Attention

<p align="center"><img src="https://raw.githubusercontent.com/ConradSun/NuwaStone/main/Docs/AuthAllert.png" width=512></p>

NuwaStone wont't let unsigned app run without your authorization, but the app will run just this time if you do not authorize within 30 seconds.

## Preferences

Select 'Preferences' or 'Settings' from the status bar menu of **NuwaClient** application to check or update user preferences. It provides 'Basic Settings', 'Event Muting' and 'System Info' sub viewers.

<p align="center"><img src="https://raw.githubusercontent.com/ConradSun/NuwaStone/main/Docs/Preferences-BasicSettings.png" width=512></p>
<p align="center"><img src="https://raw.githubusercontent.com/ConradSun/NuwaStone/main/Docs/Preferences-EventMuting.png" width=512></p>
<p align="center"><img src="https://raw.githubusercontent.com/ConradSun/NuwaStone/main/Docs/Preferences-SystemInfo.png" width=512></p>

Sub viewer of 'Event Muting' support filtering events as below:

- Mute file events by file paths or process paths
- Mute network events by process paths or remote ip addresses
- Mute process events by allowing or denying binary paths