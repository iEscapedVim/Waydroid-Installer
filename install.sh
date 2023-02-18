#!/bin/bash

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Determine the current kernel
current_kernel=$(uname -r)
echo "Current kernel version is $current_kernel"

# Check if the current kernel is supported
if ! pacman -Qs "linux" > /dev/null && ! pacman -Qs "linux-lts" > /dev/null && ! pacman -Qs "linux-zen" > /dev/null && ! pacman -Qs "linux-xanmod-anbox" > /dev/null ; then
    echo "This script only supports linux linux-lts, linux-zen, and linux-xanmod-anbox kernels"
    exit 1
fi

# Install required dependencies
pacman -Syyu --noconfirm yay
yay -S --noconfirm dkms android-tools

# Install kernel headers if needed
if pacman -Qs "linux" > /dev/null ; then
    if pacman -Qs "linux-headers" > /dev/null ; then
        echo "linux-headers is already installed"
    else
        pacman -S --noconfirm linux-headers
    fi
    dkms install binder_linux/1.3.1 -k $current_kernel
    dkms install ashmem_linux/1.3.1 -k $current_kernel
elif pacman -Qs "linux-lts" > /dev/null ; then
    if pacman -Qs "linux-lts-headers" > /dev/null ; then
        echo "linux-lts-headers is already installed"
    else
        pacman -S --noconfirm linux-lts-headers
    fi
    dkms install binder_linux/1.3.1 -k $current_kernel
    dkms install ashmem_linux/1.3.1 -k $current_kernel
elif pacman -Qs "linux-zen" > /dev/null ; then
    if pacman -Qs "linux-zen-headers" > /dev/null ; then
        echo "linux-zen-headers is already installed"
    else
        pacman -S --noconfirm linux-zen-headers
elif pacman -Qs "linux-xanmod-anbox" > /dev/null ; then
    if pacman -Qs "linux-xanmod-headers" > /dev/null ; then
        echo "linux-xanmod-headers is already installed"
    else
        yay -S --noconfirm linux-xanmod-anbox linux-xanmod-headers
    fi
    dkms install binder_linux/1.3.1 -k $current_kernel-xanmodanbox
    dkms install ashmem_linux/1.3.1 -k $current_kernel-xanmodanbox
else
    echo "Unsupported kernel"
    exit 1
fi

# Install Waydroid
yay -S --noconfirm waydroid

# Run Waydroid init
echo "Do you want to run Waydroid init? (y/n)"
read run_init

if [[ $run_init =~ ^[Yy]$ ]]; then
    echo "Which version of Waydroid do you want to install? (Vanilla or with GAPPS)"
    echo "Vanilla version doesn't include Google Apps, while the version with GAPPS does"
    read waydroid_version
    if [[ $waydroid_version =~ ^[Gg]$ ]]; then
        waydroid init -s GAPPS -f
    else
        waydroid init -f
    fi
fi

# Ask user if they want to start and enable the waydroid-container.service
echo "Do you want to start and enable waydroid-container.service? (y/n)"
read start_service

if [[ $start_service =~ ^[Yy]$ ]]; then
    # Start and enable waydroid-container.service
    sudo systemctl start waydroid-container.service
    sudo systemctl enable waydroid-container.service
    echo "waydroid-container.service has been started and enabled."
else
    echo "waydroid-container.service has not been started or enabled."
fi

echo "Installation complete. Reboot the system to start using Waydroid."