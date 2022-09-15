#!/usr/bin/env bash

sudo cp /Applications/NuwaClient.app/Contents/Resources/NuwaService.app/Contents/Resources/com.nuwastone.service.plist /Library/LaunchDaemons

version=$(uname -r)
version=${version:0:2}
version=$(($version-4))

if (($version < 12))
then
    echo "Unsupport OS."
    exit -1
else
    if (($version < 16))
    then
        echo "Using kext as backend."
        codesign -f -s "-" /Applications/NuwaClient.app/Contents/Resources/NuwaService.app/
        codesign -f -s "-" /Applications/NuwaClient.app
        sudo chown -R root:wheel /Applications/NuwaClient.app/Contents/Resources/NuwaService.app/Contents/PlugIns/NuwaStone.kext
        sudo chmod -R 755 /Applications/NuwaClient.app/Contents/Resources/NuwaService.app/Contents/PlugIns/NuwaStone.kext
        sudo kextload /Applications/NuwaClient.app/Contents/Resources/NuwaService.app/Contents/PlugIns/NuwaStone.kext
    else
        echo "Using sext as backend."
    fi
fi

sudo launchctl load /Library/LaunchDaemons/com.nuwastone.service.plist
