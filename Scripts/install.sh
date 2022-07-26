#!/bin/zsh

cd .
cp -r ./NuwaClient.app /Applications
sudo chown -R root:wheel /Applications/NuwaClient.app/Contents/PlugIns/com.nuwastone.kext
sudo chmod -R 755 /Applications/NuwaClient.app/Contents/PlugIns/com.nuwastone.kext

sudo kextload /Applications/NuwaClient.app/Contents/PlugIns/com.nuwastone.kext
