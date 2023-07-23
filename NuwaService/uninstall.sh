#！/bin/zsh

sudo launchctl remove com.nuwastone.service
sudo rm /Library/LaunchDaemons/com.nuwastone.service.plist

killall NuwaClient
sudo rm -rf /Applications/NuwaClient.app
