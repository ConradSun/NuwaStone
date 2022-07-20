#!/bin/zsh

sudo launchctl remove com.nuwastone.client
sudo rm /Library/LaunchDaemons/com.nuwastone.client.plist
sudo kextunload -b com.nuwastone
sudo rm -rf /Applications/NuwaClient.app
