#!/bin/zsh

cd .
codesign -f -s "-" ./NuwaClient.app/Contents/Resources/NuwaService.app/
codesign -f -s "-" ./NuwaClient.app
cp -r ./NuwaClient.app /Applications

sudo cp ./com.nuwastone.service.plist /Library/LaunchDaemons

sudo chown -R root:wheel /Applications/NuwaClient.app/Contents/Resources/NuwaService.app/Contents/PlugIns/NuwaStone.kext
sudo chmod -R 755 /Applications/NuwaClient.app/Contents/Resources/NuwaService.app/Contents/PlugIns/NuwaStone.kext

sudo kextload /Applications/NuwaClient.app/Contents/Resources/NuwaService.app/Contents/PlugIns/NuwaStone.kext
sudo launchctl load /Library/LaunchDaemons/com.nuwastone.service.plist
