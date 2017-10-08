#!/usr/bin/env bash

###############################################################################
# Setup script for the OS X environment
###############################################################################

HOSTNAME='bkrueger'
NTP='time.nist.gov'
TIMEZONE='America/Los_Angeles'

########## Helper functions ##########
black='\033[0;30m'
white='\033[0;37m'
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
magenta='\033[0;35m'
cyan='\033[0;36m'
reset=`tput sgr0`
 
console() {
  case "$2" in
    error)
      echo "${red}${1}${reset}"
    ;;
    progress)
      echo "- ${cyan}${1}${reset}"
    ;;
    success)
      echo "${green}${1}${reset}"
    ;;
    warning)
      echo "${yellow}${1}${reset}"
    ;;
    *)
      echo "\n${blue}${1}${reset}"
  esac
}

# Close any open System Preferences panes, to prevent them from overriding
# settings we’re about to change
osascript -e 'tell application "System Preferences" to quit'

# Ask for the administrator password upfront
sudo -v

# Keep-alive: update existing `sudo` time stamp until script has finished
while true; do sudo -n true; sleep 30; kill -0 "$$" || exit; done 2>/dev/null &


###############################################################################
# Hardware & OS Configuration
###############################################################################


console 'Configuring system parameters'

# These no longer work because of the System Integrity Protection system
#console 'Enable verbose boot' 'progress'
#sudo nvram boot-args="-v"
#console 'Enable the MacBook Air SuperDrive' 'progress'
#sudo nvram boot-args="mbasd=1"

console 'Set computer name' 'progress'
sudo scutil --set ComputerName $HOSTNAME
sudo scutil --set HostName $HOSTNAME
sudo scutil --set LocalHostName $HOSTNAME
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string $HOSTNAME

# Set the timezone; see `sudo systemsetup -listtimezones` for other values
console 'Set timezone' 'progress'
sudo systemsetup -settimezone $TIMEZONE > /dev/null

console 'Set NTP server' 'progress'
sudo systemsetup -setnetworktimeserver $NTP


###############################################################################
# Menu Bar
###############################################################################

console 'Configuring the menu bar'

console 'Hide unwanted menu icons' 'progress'
defaults -currentHost write com.apple.systemuiserver dontAutoLoad -array \
	"/System/Library/CoreServices/Menu Extras/TimeMachine.menu" \
    "/System/Library/CoreServices/Menu Extras/Volume.menu" \
    "/System/Library/CoreServices/Menu Extras/Displays.menu" \
	"/System/Library/CoreServices/Menu Extras/Bluetooth.menu" \
  	"/System/Library/CoreServices/Menu Extras/User.menu"

console 'Re-order menu icons' 'progress'
defaults write com.apple.systemuiserver menuExtras -array \
	"/System/Library/CoreServices/Menu Extras/AirPort.menu" \
	"/System/Library/CoreServices/Menu Extras/Clock.menu" \
	"/System/Library/CoreServices/Menu Extras/Battery.menu"

console 'Configure the battery icon' 'progress'
defaults write com.apple.menuextra.battery ShowPercent -string "Yes"

console 'Configure the clock' 'progress'
defaults write com.apple.menuextra.clock "DateFormat" -string "MMM d hh:mm a"
defaults write com.apple.menuextra.clock "FlashDateSeparators" 0
defaults write com.apple.menuextra.clock "IsAnalog" 0

killall -HUP SystemUIServer


###############################################################################
# UI
###############################################################################

console 'Configuring UI options'

console 'Expand save panel by default' 'progress'
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

console 'Expand print panel by default' 'progress'
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

console 'Save to disk (not to iCloud) by default' 'progress'
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

console 'Automatically quit printer app once the print jobs complete' 'progress'
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

console 'Disable automatic termination of inactive apps' 'progress'
defaults write NSGlobalDomain NSDisableAutomaticTermination -bool true

console 'Disable the crash reporter' 'progress'
defaults write com.apple.CrashReporter DialogType -string "none"

console 'Set Help Viewer windows to non-floating mode' 'progress'
defaults write com.apple.helpviewer DevMode -bool true

console 'Disable smart quotes as they’re annoying when typing code' 'progress'
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

console 'Disable smart dashes as they’re annoying when typing code' 'progress'
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

console 'Disable auto-correct' 'progress'
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

console 'Reveal IP address, hostname, OS version in the login window' 'progress'
sudo defaults write /Library/Preferences/com.apple.loginwindow AdminHostInfo HostName

killall -HUP SystemUIServer


###############################################################################
# Full Disk Encryption
###############################################################################


if test ! $(sudo fdesetup status|grep On); then
	console 'Enabling Full Disk Encryption'
	sudo fdesetup enable -defer $HOME/Documents/FileVaultRecovery.plist
	sudo defaults write /Library/Preferences/com.apple.loginwindow DisableFDEAutoLogin -bool YES
fi


###############################################################################
# Install XCode
###############################################################################


console 'Installing xcode'
sudo xcode-select --install
sudo xcodebuild -license accept


###############################################################################
# Install Homebrew
###############################################################################


if test ! $(which brew); then
	console 'Setting up homebrew'

	console 'Install brew' 'progress'
	/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

	console 'Update brew' 'progress'
	brew update

	console 'Install mas' 'progress'
	brew install mas

	console 'Run brew bundle' 'progress'
	brew bundle -v --file=OSX/Brewfile

	console 'Link apps' 'progress'
	brew link curl --force

	if [ ! -z $PERSONAL ]; then
		console 'Install additional apps for personal use' 'progress'
		brew bundle -v --file=OSX/Brewfile.home
	fi

	console 'Writing Brewfile'
	brew dump --file=$HOME/.Brewfile

	console 'Brew cleanup'
	brew cleanup

	console 'Brew cask cleanup'
	brew cask cleanup
fi


###############################################################################
# Firewall rules
###############################################################################

console 'Configuring the firewall and adding rules'

socketfilterfw='/usr/libexec/ApplicationFirewall/socketfilterfw'
allow_apps=(
	/usr/local/bin/iperf3
	/usr/local/bin/consul
	/usr/local/bin/node
)

console 'Enable firewall' 'progress'
$socketfilterfw --setglobalstate on
console 'Enable stealth mode' 'progress'
$socketfilterfw --setstealthmode on
console 'Enable logging' 'progress'
$socketfilterfw --setloggingmode on
$socketfilterfw --setloggingopt brief

for app in ${allow_apps[@]}; do
	if [ -f $app ]; then
		console "Allow $app" 'progress'
		$socketfilterfw -s $app
		$socketfilterfw --add $app
	fi
done;


###############################################################################
# Trackpad, mouse, keyboard, Bluetooth accessories, and input
###############################################################################

console 'Configuring input options'

console 'enable tap to click for this user and for the login screen' 'progress'
defaults write com.apple.driver.AppleMultitouchTrackpad Clicking -int 1
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

console 'Increase sound quality for Bluetooth headphones/headsets' 'progress'
defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Min (editable)" -int 40

console 'Enable full keyboard access for all controls (tab in modal dialogs)' 'progress'
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

console 'Stop iTunes from responding to the keyboard media keys' 'progress'
launchctl unload -w /System/Library/LaunchAgents/com.apple.rcd.plist 2> /dev/null

console 'Disable press-and-hold for keys in favor of key repeat' 'progress'
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

console 'Set a fast keyboard repeat rate' 'progress'
defaults write NSGlobalDomain KeyRepeat -int 1
defaults write NSGlobalDomain InitialKeyRepeat -int 10

# Capslock to Control

# ioreg -n IOHIDKeyboard -r | grep -e 'class IOHIDKeyboard' -e VendorID\" -e Product

# defaults -currentHost write -g com.apple.keyboard.modifiermapping.1452-682-0 -array-add '<dict><key>HIDKeyboardModifierMappingDst</key><integer>-1</integer><key>HIDKeyboardModifierMappingSrc</key><integer>0</integer></dict>'


###############################################################################
# Screen
###############################################################################

console 'Configuring screen options'

console 'Set screen capture target directory' 'progress'
mkdir -p $HOME/Pictures/Screenshots
defaults write com.apple.screencapture location -string "${HOME}/Pictures/Screenshots"

screencap_format='png'
# other options: BMP, GIF, JPG, PDF, TIFF
console "Save screenshots in $screencap_format format" 'progress'
defaults write com.apple.screencapture type -string $screencap_format

console 'Disable shadow in screenshots' 'progress'
defaults write com.apple.screencapture disable-shadow -bool true

console 'Enable subpixel font rendering on non-Apple LCDs' 'progress'
defaults write NSGlobalDomain AppleFontSmoothing -int 2

console 'Enable HiDPI display modes (requires restart)' 'progress'
sudo defaults write /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled -bool true


###############################################################################
# Finder
###############################################################################

console 'Setting Finder options'

console 'Set Home as the default location for new Finder windows' 'progress'
# For other paths, use `PfLo` and `file:///full/path/here/`
defaults write com.apple.finder NewWindowTarget -string "PfDe"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/"

console 'Show icons for hard drives, servers, and removable media on the desktop' 'progress'
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowMountedServersOnDesktop -bool true
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true

console "Don't show hidden files by default" 'progress'
defaults write com.apple.finder AppleShowAllFiles -bool false

console 'Show all filename extensions' 'progress'
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

console 'Show status bar' 'progress'
defaults write com.apple.finder ShowStatusBar -bool true

console 'show path bar' 'progress'
defaults write com.apple.finder ShowPathbar -bool true

console 'Display full POSIX path as Finder window title' 'progress'
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

console 'Avoid creating .DS_Store files on network or USB volumes' 'progress'
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

console 'Disable the warning when changing a file extension' 'progress'
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

console 'Show item info below desktop icons' 'progress'
/usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:showItemInfo true" ~/Library/Preferences/com.apple.finder.plist

console 'Enable snap-to-grid for desktop icons' 'progress'
/usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist

console 'Disable the warning before emptying the Trash' 'progress'
defaults write com.apple.finder WarnOnEmptyTrash -bool false

console 'Empty Trash securely by default' 'progress'
defaults write com.apple.finder EmptyTrashSecurely -bool true

console 'Require password immediately after sleep or screen saver begins' 'progress'
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 2

console 'Enable tap to click (Trackpad)' 'progress'
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true

console 'Map bottom right Trackpad corner to right-click' 'progress'
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadCornerSecondaryClick -int 2
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true

console 'Show the ~/Library folder' 'progress'
chflags nohidden ~/Library

console 'Show the /Volumes folder' 'progress'
sudo chflags nohidden /Volumes


###############################################################################
# Hot Corners
###############################################################################

console 'Configure hot corners'

# Hot corners
# Possible values:
#  0: no-op
#  2: Mission Control
#  3: Show application windows
#  4: Desktop
#  5: Start screen saver
#  6: Disable screen saver
#  7: Dashboard
# 10: Put display to sleep
# 11: Launchpad
# 12: Notification Center

console 'Top left screen corner → Mission Control' 'progress'
defaults write com.apple.dock wvous-tl-corner -int 2
defaults write com.apple.dock wvous-tl-modifier -int 0

console 'Bottom left screen corner → Start screen saver' 'progress'
defaults write com.apple.dock wvous-bl-corner -int 5
defaults write com.apple.dock wvous-bl-modifier -int 0


###############################################################################
# Docks and Spaces
###############################################################################

console 'Configuring Docks and Spaces'

console 'Don’t automatically rearrange Spaces based on most recent use' 'progress'
defaults write com.apple.dock mru-spaces -bool false

console 'Remove the auto-hiding Dock delay' 'progress'
defaults write com.apple.dock autohide-delay -float 0.1
#console 'Remove the animation when hiding/showing the Dock' 'progress'
#defaults write com.apple.dock autohide-time-modifier -float 0

console 'Automatically hide and show the Dock' 'progress'
defaults write com.apple.dock autohide -bool true

console 'Make Dock icons of hidden applications translucent' 'progress'
defaults write com.apple.dock showhidden -bool true

killall -HUP Dock


###############################################################################
# Safari & WebKit
###############################################################################

console 'Configuring Safari & WebKit'

console 'Privacy: don’t send search queries to Apple' 'progress'
defaults write com.apple.Safari UniversalSearchEnabled -bool false
defaults write com.apple.Safari SuppressSearchSuggestions -bool true

console 'Press Tab to highlight each item on a web page' 'progress'
defaults write com.apple.Safari WebKitTabToLinksPreferenceKey -bool true
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2TabsToLinks -bool true

console 'Show the full URL in the address bar (note: this still hides the scheme)' 'progress'
defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true

console 'Set Safari’s home page to `about:blank` for faster loading' 'progress'
defaults write com.apple.Safari HomePage -string "about:blank"

console 'Prevent Safari from opening ‘safe’ files automatically after downloading' 'progress'
defaults write com.apple.Safari AutoOpenSafeDownloads -bool false

console 'Allow hitting the Backspace key to go to the previous page in history' 'progress'
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2BackspaceKeyNavigationEnabled -bool true

console 'Hide Safari’s bookmarks bar by default' 'progress'
defaults write com.apple.Safari ShowFavoritesBar -bool false

console 'Hide Safari’s sidebar in Top Sites' 'progress'
defaults write com.apple.Safari ShowSidebarInTopSites -bool false

console 'Disable Safari’s thumbnail cache for History and Top Sites' 'progress'
defaults write com.apple.Safari DebugSnapshotsUpdatePolicy -int 2

console 'Enable Safari’s debug menu' 'progress'
defaults write com.apple.Safari IncludeInternalDebugMenu -bool true

console 'Make Safari’s search banners default to Contains instead of Starts With' 'progress'
defaults write com.apple.Safari FindOnPageMatchesWordStartsOnly -bool false

console 'Remove useless icons from Safari’s bookmarks bar' 'progress'
defaults write com.apple.Safari ProxiesInBookmarksBar "()"

console 'Enable the Develop menu and the Web Inspector in Safari' 'progress'
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true

console 'Add a context menu item for showing the Web Inspector in web views' 'progress'
defaults write NSGlobalDomain WebKitDeveloperExtras -bool true

console 'Enable continuous spellchecking' 'progress'
defaults write com.apple.Safari WebContinuousSpellCheckingEnabled -bool true
console 'Disable auto-correct' 'progress'
defaults write com.apple.Safari WebAutomaticSpellingCorrectionEnabled -bool false

console 'Disable AutoFill' 'progress'
defaults write com.apple.Safari AutoFillFromAddressBook -bool false
defaults write com.apple.Safari AutoFillPasswords -bool false
defaults write com.apple.Safari AutoFillCreditCardData -bool false
defaults write com.apple.Safari AutoFillMiscellaneousForms -bool false

console 'Warn about fraudulent websites' 'progress'
defaults write com.apple.Safari WarnAboutFraudulentWebsites -bool true

console 'Disable plug-ins' 'progress'
defaults write com.apple.Safari WebKitPluginsEnabled -bool false
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2PluginsEnabled -bool false

console 'Disable Java' 'progress'
defaults write com.apple.Safari WebKitJavaEnabled -bool false
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaEnabled -bool false

console 'Block pop-up windows' 'progress'
defaults write com.apple.Safari WebKitJavaScriptCanOpenWindowsAutomatically -bool false
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaScriptCanOpenWindowsAutomatically -bool false

console 'Enable “Do Not Track”' 'progress'
defaults write com.apple.Safari SendDoNotTrackHTTPHeader -bool true

console 'Update extensions automatically' 'progress'
defaults write com.apple.Safari InstallExtensionUpdatesAutomatically -bool true

killall -HUP Safari


###############################################################################
# Spotlight
###############################################################################

console 'Configuring Spotlight'

# console 'Hide Spotlight tray-icon (and subsequent helper)' 'progress'
#sudo chmod 600 /System/Library/CoreServices/Search.bundle/Contents/MacOS/Search

console 'Disable Spotlight indexing for any mounted volume that has never been indexed before' 'progress'
# Use `sudo mdutil -i off "/Volumes/foo"` to stop indexing any volume.
sudo defaults write /.Spotlight-V100/VolumeConfiguration Exclusions -array "/Volumes"

console 'Change indexing order and disable some search results' 'progress'
# Yosemite-specific search results (remove them if you are using macOS 10.9 or older):
# 	MENU_DEFINITION
# 	MENU_CONVERSION
# 	MENU_EXPRESSION
# 	MENU_SPOTLIGHT_SUGGESTIONS (send search queries to Apple)
# 	MENU_WEBSEARCH             (send search queries to Apple)
# 	MENU_OTHER
defaults write com.apple.spotlight orderedItems -array \
	'{"enabled" = 1;"name" = "APPLICATIONS";}' \
	'{"enabled" = 1;"name" = "SYSTEM_PREFS";}' \
	'{"enabled" = 1;"name" = "DIRECTORIES";}' \
	'{"enabled" = 1;"name" = "PDF";}' \
	'{"enabled" = 1;"name" = "FONTS";}' \
	'{"enabled" = 0;"name" = "DOCUMENTS";}' \
	'{"enabled" = 0;"name" = "MESSAGES";}' \
	'{"enabled" = 0;"name" = "CONTACT";}' \
	'{"enabled" = 0;"name" = "EVENT_TODO";}' \
	'{"enabled" = 0;"name" = "IMAGES";}' \
	'{"enabled" = 0;"name" = "BOOKMARKS";}' \
	'{"enabled" = 0;"name" = "MUSIC";}' \
	'{"enabled" = 0;"name" = "MOVIES";}' \
	'{"enabled" = 0;"name" = "PRESENTATIONS";}' \
	'{"enabled" = 0;"name" = "SPREADSHEETS";}' \
	'{"enabled" = 0;"name" = "SOURCE";}' \
	'{"enabled" = 0;"name" = "MENU_DEFINITION";}' \
	'{"enabled" = 0;"name" = "MENU_OTHER";}' \
	'{"enabled" = 0;"name" = "MENU_CONVERSION";}' \
	'{"enabled" = 0;"name" = "MENU_EXPRESSION";}' \
	'{"enabled" = 0;"name" = "MENU_WEBSEARCH";}' \
	'{"enabled" = 0;"name" = "MENU_SPOTLIGHT_SUGGESTIONS";}'

console 'Load new settings before rebuilding the index' 'progress'
killall -HUP mds > /dev/null 2>&1

console 'Make sure indexing is enabled for the main volume' 'progress'
mdutil -i on / > /dev/null

console 'Rebuild the index from scratch' 'progress'
mdutil -E / > /dev/null


###############################################################################
# Terminal & iTerm
###############################################################################

console 'Configuring Terminals'

console 'Enable Secure Keyboard Entry in Terminal.app' 'progress'
# See: https://security.stackexchange.com/a/47786/8918
defaults write com.apple.terminal SecureKeyboardEntry -bool true

console 'Disable the annoying line marks' 'progress'
defaults write com.apple.Terminal ShowLineMarks -int 0

console 'Don’t display the annoying prompt when quitting iTerm' 'progress'
defaults write com.googlecode.iterm2 PromptOnQuit -bool false


###############################################################################
# Time Machine
###############################################################################

console 'Configuring Time Machine'

console 'Prevent Time Machine from prompting to use new hard drives as backup volume' 'progress'
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

console 'Disable local Time Machine backups' 'progress'
hash tmutil &> /dev/null && sudo tmutil disablelocal


###############################################################################
# Activity Monitor
###############################################################################

console 'Configuring Activity Monitor'

console 'Show the main window when launching Activity Monitor' 'progress'
defaults write com.apple.ActivityMonitor OpenMainWindow -bool true

console 'Visualize CPU usage in the Activity Monitor Dock icon' 'progress'
defaults write com.apple.ActivityMonitor IconType -int 5

console 'Show all processes in Activity Monitor' 'progress'
defaults write com.apple.ActivityMonitor ShowCategory -int 0

console 'Sort Activity Monitor results by CPU usage' 'progress'
defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage"
defaults write com.apple.ActivityMonitor SortDirection -int 0


###############################################################################
# Address Book, Dashboard, iCal, TextEdit, and Disk Utility
###############################################################################

console 'Configuring Address Book, Dashboard, iCal, TextEdit, and Disk Utility'

console 'Enable the debug menu in Address Book' 'progress'
defaults write com.apple.addressbook ABShowDebugMenu -bool true

console 'Enable Dashboard dev mode (allows keeping widgets on the desktop)' 'progress'
defaults write com.apple.dashboard devmode -bool true

console 'Enable the debug menu in iCal (pre-10.8)' 'progress'
defaults write com.apple.iCal IncludeDebugMenu -bool true

console 'Use plain text mode for new TextEdit documents' 'progress'
defaults write com.apple.TextEdit RichText -int 0
console 'Open and save files as UTF-8 in TextEdit' 'progress'
defaults write com.apple.TextEdit PlainTextEncoding -int 4
defaults write com.apple.TextEdit PlainTextEncodingForWrite -int 4

console 'Enable the debug menu in Disk Utility' 'progress'
defaults write com.apple.DiskUtility DUDebugMenuEnabled -bool true
defaults write com.apple.DiskUtility advanced-image-options -bool true

console 'Auto-play videos when opened with QuickTime Player' 'progress'
defaults write com.apple.QuickTimePlayerX MGPlayMovieOnOpen -bool true


###############################################################################
# Mac App Store                                                               #
###############################################################################

console 'Configuring Mac App Store'

console 'Enable the WebKit Developer Tools in the Mac App Store' 'progress'
defaults write com.apple.appstore WebKitDeveloperExtras -bool true

console 'Enable Debug Menu in the Mac App Store' 'progress'
defaults write com.apple.appstore ShowDebugMenu -bool true

console 'Enable the automatic update check' 'progress'
defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true

console 'Check for software updates daily, not just once per week' 'progress'
defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1

console 'Download newly available updates in background' 'progress'
defaults write com.apple.SoftwareUpdate AutomaticDownload -int 1

console 'Install System data files & security updates' 'progress'
defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -int 1

console 'Automatically download apps purchased on other Macs' 'progress'
defaults write com.apple.SoftwareUpdate ConfigDataInstall -int 0

console 'Turn on app auto-update' 'progress'
defaults write com.apple.commerce AutoUpdate -bool true

console 'Allow the App Store to reboot machine on macOS updates - false' 'progress'
defaults write com.apple.commerce AutoUpdateRestartRequired -bool false


###############################################################################
# Google Chrome & Google Chrome Canary
###############################################################################

console 'Configuring Google Chrome'

console 'Disable the all too sensitive backswipe on trackpads' 'progress'
defaults write com.google.Chrome AppleEnableSwipeNavigateWithScrolls -bool false
defaults write com.google.Chrome.canary AppleEnableSwipeNavigateWithScrolls -bool false

console 'Disable the all too sensitive backswipe on Magic Mouse' 'progress'
defaults write com.google.Chrome AppleEnableMouseSwipeNavigateWithScrolls -bool false
defaults write com.google.Chrome.canary AppleEnableMouseSwipeNavigateWithScrolls -bool false

console 'Use the system-native print preview dialog' 'progress'
defaults write com.google.Chrome DisablePrintPreview -bool true
defaults write com.google.Chrome.canary DisablePrintPreview -bool true

console 'Expand the print dialog by default' 'progress'
defaults write com.google.Chrome PMPrintingExpandedStateForPrint2 -bool true
defaults write com.google.Chrome.canary PMPrintingExpandedStateForPrint2 -bool true


###############################################################################
# GPGMail 2
###############################################################################

console 'Configuring GPGMail'

console 'Disable signing emails by default' 'progress'
defaults write ~/Library/Preferences/org.gpgtools.gpgmail SignNewEmailsByDefault -bool false


###############################################################################
# Transmission.app                                                            #
###############################################################################

console 'Configuring Transmission App'

console 'Use `~/Documents/Torrents` to store incomplete downloads' 'progress'
defaults write org.m0k.transmission UseIncompleteDownloadFolder -bool true
defaults write org.m0k.transmission IncompleteDownloadFolder -string "${HOME}/Documents/Torrents"

console 'Don’t prompt for confirmation before downloading' 'progress'
defaults write org.m0k.transmission DownloadAsk -bool false
defaults write org.m0k.transmission MagnetOpenAsk -bool false

console 'Trash original torrent files' 'progress'
defaults write org.m0k.transmission DeleteOriginalTorrent -bool true

console 'Hide the donate message' 'progress'
defaults write org.m0k.transmission WarningDonate -bool false
console 'Hide the legal disclaimer' 'progress'
defaults write org.m0k.transmission WarningLegal -bool false

console 'Use IP block list' 'progress'
# Source: https://giuliomac.wordpress.com/2014/02/19/best-blocklist-for-transmission/
defaults write org.m0k.transmission BlocklistNew -bool true
defaults write org.m0k.transmission BlocklistURL -string "http://john.bitsurge.net/public/biglist.p2p.gz"
defaults write org.m0k.transmission BlocklistAutoUpdate -bool true


###############################################################################
# Spectacle.app                                                               #
###############################################################################

console 'Configuring Spectacle App'

# Set up my preferred keyboard shortcuts
#defaults write com.divisiblebyzero.Spectacle MakeLarger -data 62706c6973743030d40102030405061819582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708101155246e756c6cd4090a0b0c0d0e0d0f596d6f64696669657273546e616d65576b6579436f64655624636c6173731000800280035a4d616b654c6172676572d2121314155a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21617585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11a1b54726f6f74800108111a232d32373c424b555a62696b6d6f7a7f8a939c9fa8b1c3c6cb0000000000000101000000000000001c000000000000000000000000000000cd
#defaults write com.divisiblebyzero.Spectacle MakeSmaller -data 62706c6973743030d40102030405061819582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708101155246e756c6cd4090a0b0c0d0e0d0f596d6f64696669657273546e616d65576b6579436f64655624636c6173731000800280035b4d616b65536d616c6c6572d2121314155a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21617585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11a1b54726f6f74800108111a232d32373c424b555a62696b6d6f7b808b949da0a9b2c4c7cc0000000000000101000000000000001c000000000000000000000000000000ce
#defaults write com.divisiblebyzero.Spectacle MoveToBottomDisplay -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c6173731119008002107d80035f10134d6f7665546f426f74746f6d446973706c6179d2131415165a24636c6173736e616d655824636c61737365735d5a65726f4b6974486f744b6579a217185d5a65726f4b6974486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e7072888d98a1afb2c0c9dbdee30000000000000101000000000000001d000000000000000000000000000000e5
#defaults write com.divisiblebyzero.Spectacle MoveToBottomHalf -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c6173731119008002107d80035f10104d6f7665546f426f74746f6d48616c66d2131415165a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21718585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e7072858a959ea7aab3bcced1d60000000000000101000000000000001d000000000000000000000000000000d8
#defaults write com.divisiblebyzero.Spectacle MoveToCenter -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c6173731119008002100880035c4d6f7665546f43656e746572d2131415165a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21718585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e70727f848f98a1a4adb6c8cbd00000000000000101000000000000001d000000000000000000000000000000d2
#defaults write com.divisiblebyzero.Spectacle MoveToFullscreen -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c6173731119008002102e80035f10104d6f7665546f46756c6c73637265656ed2131415165a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21718585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e7072858a959ea7aab3bcced1d60000000000000101000000000000001d000000000000000000000000000000d8
#defaults write com.divisiblebyzero.Spectacle MoveToLeftDisplay -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c6173731119008002107b80035f10114d6f7665546f4c656674446973706c6179d2131415165a24636c6173736e616d655824636c61737365735d5a65726f4b6974486f744b6579a217185d5a65726f4b6974486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e7072868b969fadb0bec7d9dce10000000000000101000000000000001d000000000000000000000000000000e3
#defaults write com.divisiblebyzero.Spectacle MoveToLeftHalf -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c6173731119008002107b80035e4d6f7665546f4c65667448616c66d2131415165a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21718585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e70728186919aa3a6afb8cacdd20000000000000101000000000000001d000000000000000000000000000000d4
#defaults write com.divisiblebyzero.Spectacle MoveToLowerLeft -data 62706c6973743030d40102030405061a1b582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c6173731113008002107b80035f100f4d6f7665546f4c6f7765724c656674d2131415165a24636c6173736e616d655824636c61737365735d5a65726f4b6974486f744b6579a31718195d5a65726f4b6974486f744b6579585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11c1d54726f6f74800108111a232d32373c424b555a62696c6e70728489949dabafbdc6cfe1e4e90000000000000101000000000000001e000000000000000000000000000000eb
#defaults write com.divisiblebyzero.Spectacle MoveToLowerRight -data 62706c6973743030d40102030405061a1b582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c6173731113008002107c80035f10104d6f7665546f4c6f7765725269676874d2131415165a24636c6173736e616d655824636c61737365735d5a65726f4b6974486f744b6579a31718195d5a65726f4b6974486f744b6579585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11c1d54726f6f74800108111a232d32373c424b555a62696c6e7072858a959eacb0bec7d0e2e5ea0000000000000101000000000000001e000000000000000000000000000000ec
#defaults write com.divisiblebyzero.Spectacle MoveToNextDisplay -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c6173731118008002107c80035f10114d6f7665546f4e657874446973706c6179d2131415165a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21718585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e7072868b969fa8abb4bdcfd2d70000000000000101000000000000001d000000000000000000000000000000d9
#defaults write com.divisiblebyzero.Spectacle MoveToNextThird -data 62706c6973743030d40102030405061819582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708101155246e756c6cd4090a0b0c0d0e0d0f596d6f64696669657273546e616d65576b6579436f64655624636c6173731000800280035f100f4d6f7665546f4e6578745468697264d2121314155a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21617585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11a1b54726f6f74800108111a232d32373c424b555a62696b6d6f8186919aa3a6afb8cacdd20000000000000101000000000000001c000000000000000000000000000000d4
#defaults write com.divisiblebyzero.Spectacle MoveToPreviousDisplay -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c6173731118008002107b80035f10154d6f7665546f50726576696f7573446973706c6179d2131415165a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21718585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e70728a8f9aa3acafb8c1d3d6db0000000000000101000000000000001d000000000000000000000000000000dd
#defaults write com.divisiblebyzero.Spectacle MoveToPreviousThird -data 62706c6973743030d40102030405061819582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708101155246e756c6cd4090a0b0c0d0e0d0f596d6f64696669657273546e616d65576b6579436f64655624636c6173731000800280035f10134d6f7665546f50726576696f75735468697264d2121314155a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21617585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11a1b54726f6f74800108111a232d32373c424b555a62696b6d6f858a959ea7aab3bcced1d60000000000000101000000000000001c000000000000000000000000000000d8
#defaults write com.divisiblebyzero.Spectacle MoveToRightDisplay -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c6173731119008002107c80035f10124d6f7665546f5269676874446973706c6179d2131415165a24636c6173736e616d655824636c61737365735d5a65726f4b6974486f744b6579a217185d5a65726f4b6974486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e7072878c97a0aeb1bfc8dadde20000000000000101000000000000001d000000000000000000000000000000e4
#defaults write com.divisiblebyzero.Spectacle MoveToRightHalf -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c6173731119008002107c80035f100f4d6f7665546f526967687448616c66d2131415165a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21718585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e70728489949da6a9b2bbcdd0d50000000000000101000000000000001d000000000000000000000000000000d7
#defaults write com.divisiblebyzero.Spectacle MoveToTopDisplay -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c6173731119008002107e80035f10104d6f7665546f546f70446973706c6179d2131415165a24636c6173736e616d655824636c61737365735d5a65726f4b6974486f744b6579a217185d5a65726f4b6974486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e7072858a959eacafbdc6d8dbe00000000000000101000000000000001d000000000000000000000000000000e2
#defaults write com.divisiblebyzero.Spectacle MoveToTopHalf -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c6173731119008002107e80035d4d6f7665546f546f7048616c66d2131415165a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21718585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e707280859099a2a5aeb7c9ccd10000000000000101000000000000001d000000000000000000000000000000d3
#defaults write com.divisiblebyzero.Spectacle MoveToUpperLeft -data 62706c6973743030d40102030405061a1b582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c6173731111008002107b80035f100f4d6f7665546f55707065724c656674d2131415165a24636c6173736e616d655824636c61737365735d5a65726f4b6974486f744b6579a31718195d5a65726f4b6974486f744b6579585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11c1d54726f6f74800108111a232d32373c424b555a62696c6e70728489949dabafbdc6cfe1e4e90000000000000101000000000000001e000000000000000000000000000000eb
#defaults write com.divisiblebyzero.Spectacle MoveToUpperRight -data 62706c6973743030d40102030405061a1b582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c6173731111008002107c80035f10104d6f7665546f55707065725269676874d2131415165a24636c6173736e616d655824636c61737365735d5a65726f4b6974486f744b6579a31718195d5a65726f4b6974486f744b6579585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11c1d54726f6f74800108111a232d32373c424b555a62696c6e7072858a959eacb0bec7d0e2e5ea0000000000000101000000000000001e000000000000000000000000000000ec
#defaults write com.divisiblebyzero.Spectacle RedoLastMove -data 62706c6973743030d40102030405061a1b582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c617373110b008002100680035c5265646f4c6173744d6f7665d2131415165a24636c6173736e616d655824636c61737365735d5a65726f4b6974486f744b6579a31718195d5a65726f4b6974486f744b6579585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11c1d54726f6f74800108111a232d32373c424b555a62696c6e70727f848f98a6aab8c1cadcdfe40000000000000101000000000000001e000000000000000000000000000000e6
#defaults write com.divisiblebyzero.Spectacle UndoLastMove -data 62706c6973743030d40102030405061a1b582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c6173731109008002100680035c556e646f4c6173744d6f7665d2131415165a24636c6173736e616d655824636c61737365735d5a65726f4b6974486f744b6579a31718195d5a65726f4b6974486f744b6579585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11c1d54726f6f74800108111a232d32373c424b555a62696c6e70727f848f98a6aab8c1cadcdfe40000000000000101000000000000001e000000000000000000000000000000e6


###############################################################################
# Photos
###############################################################################

console 'Configuring Photos app'

console 'Prevent Photos from opening automatically when devices are plugged in' 'progress'
defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true


###############################################################################
# Useful directories
###############################################################################

console 'Setting up directories'

dirs=(
	$HOME/.bin
	$HOME/src
)
project_dirs=(
	Video-Template/Assets/{Audio,Stills,Video}
	Video-Template/Notes/
	Video-Template/Renders/{0_Trimmed,1_Defished,Final_HiRes,Final_LoRes}
	Audio-Template/Assets/{Audio,Pictures}
	Audio-Template/Notes/
	Audio-Template/Renders/{Masters,Stems}
)

for dir in ${dirs[@]}; do
	console "$dir" 'progress'
	mkdir -p $dir
done

for dir in ${project_dirs[@]}; do
	console "$HOME/Projects/$dir" 'progress'
	mkdir -p $dir
done

console 'Copying avatar photos to Pictures'
cp -v pictures/* $HOME/Pictures/

console 'Setting up blurring screensaver'
mkdir -vp $HOME/{screensaver}
cp -v OSX/scripts/blurcap.sh $HOME/.bin/
crontab -l | { cat; echo "* * * * * $HOME/.bin/blurcap.sh"; } | crontab -


###############################################################################
# Cleanup
###############################################################################

console 'Configuring the Dock'

dock_apps=(
	"file:///Applications/Self%20Service.app/"
	"file:///Applications/Launchpad.app/"
	"file:///Applications/Microsoft%20Outlook.app/"
	"file:///Applications/Franz.app/"
	"file:///Applications/Visual%20Studio%20Code.app/"
	"file:///Applications/Google%20Chrome.app/"
	"file:///Applications/iTerm.app/"
)

defaults delete com.apple.dock persistent-apps
for app in ${dock_apps[@]}; do
	console "Adding $app" 'progress'
	defaults write com.apple.dock persistent-apps -array-add \
		"{ "tile-data" = { "file-data" = { "_CFURLString" = "${app}"; "_CFURLStringType" = 15; }; }; "tile-type" = "file-tile"; }"
done

###############################################################################
# Cleanup
###############################################################################

console 'Restarting system applications'

for app in "cfprefsd" "Finder" "SystemUIServer"
do
	console $app 'progress'
	killall -HUP "${app}" > /dev/null 2>&1
done

console 'Final Notes'
console 'Some of these changes require a logout/restart to take effect.' 'warning'
console 'If you enabled Full Disk Encryption, put FileVaultRecovery.plist in a safe place' 'warning'

console '\nDone.' 'success'