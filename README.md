# AutoDroid
 AutoDroid is an automated script to install waydroid on Arch or Arch Based Linux Distros
# Overview

This shell script automates the installation of Waydroid on Arch Linux. Waydroid is an Android application compatibility layer for Linux that allows you to run Android applications on your Arch Linux desktop. This script downloads and installs Waydroid from the official GitHub repository, and starts the required services.

## Prerequisites

Before running the script, make sure that your system is up-to-date and that you have sudo privileges.

## Usage

1. Download the script:
``` 
git clone https://github.com/YasirRWebDesigner/autodroid.git 
```

2. Make the script executeable 
```  
chmod +x install.sh
```

3. Run the script
``` 
sh ./install.sh
```


# Disclaimer

The script was tested on distrobox and main system had linux-zen/zen-headers preinstalled.
The script has also been tested on bare metal Arch btw, with linux/linux-headers and linux-xanmod/linux-xanmod-headers installed.
**__Use it at your own risk.__**
