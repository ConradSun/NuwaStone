#!/bin/zsh

sudo launchctl remove com.nuwastone.daemon
sudo rm /Library/LaunchDaemons/com.nuwastone.daemon.plist

sudo kextunload -b com.nuwastone.kext
sudo rm -rf /Applications/NuwaClient.app
