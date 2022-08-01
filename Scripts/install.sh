#!/bin/zsh

cd .
cp -r ./NuwaClient.app /Applications

sudo cp ./com.nuwastone.daemon.plist /Library/LaunchDaemons

sudo chown -R root:wheel /Applications/NuwaClient.app/Contents/PlugIns/NuwaStone.kext
sudo chmod -R 755 /Applications/NuwaClient.app/Contents/PlugIns/NuwaStone.kext

sudo kextload /Applications/NuwaClient.app/Contents/PlugIns/NuwaStone.kext
sudo launchctl load /Library/LaunchDaemons/com.nuwastone.daemon.plist
