#!/bin/zsh

cd .
sudo cp ./com.nuwastone.client.plist /Library/LaunchDaemons
sudo cp -r ./NuwaClient.app /Applications
sudo chown root:wheel /Library/LaunchDaemons/com.nuwastone.client.plist
sudo chown -R root:wheel /Applications/NuwaClient.app/Contents/PlugIns/com.nuwastone.kext
sudo chmod -R 755 /Applications/NuwaClient.app/Contents/PlugIns/com.nuwastone.kext

sudo launchctl load /Library/LaunchDaemons/com.nuwastone.client.plist
