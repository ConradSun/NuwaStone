#！/bin/zsh

sudo launchctl remove com.nuwastone.service
sudo rm /Library/LaunchDaemons/com.nuwastone.service.plist

pkill -9 NuwaClient
sudo rm -rf /Applications/NuwaClient.app
