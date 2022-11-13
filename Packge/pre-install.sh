#!/usr/bin/env bash

sudo launchctl remove com.nuwastone.service
sudo rm /Library/LaunchDaemons/com.nuwastone.service.plist

version=$(uname -r)
version=${version:0:2}
version=$(($version-4))

if (($version < 13))
then
    echo "Unsupport OS."
    exit -1
else
    if (($version < 16))
    then
        echo "Unload kext."
        sudo kextunload -b com.nuwastone.service.eps
    else
        echo "Uninstall sext."
        sudo systemextensionsctl uninstall - com.nuwastone.service.eps
    fi
fi

pkill -9 NuwaClient
sudo rm -rf /Applications/NuwaClient.app

