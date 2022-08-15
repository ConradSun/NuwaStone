#!/bin/zsh

sudo launchctl remove com.nuwastone.service
sudo rm /Library/LaunchDaemons/com.nuwastone.service.plist

sudo kextunload -b com.nuwastone.service.eps
sudo rm -rf /Applications/NuwaClient.app
