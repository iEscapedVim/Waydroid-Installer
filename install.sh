#!/usr/bin/env bash
set -xe
git clone https://aur.archlinux.org/python-pyclip.git
cd python-pyclip || exit
makepkg -cfsi
cd ..
sudo rm -rf python-pyclip

sudo pacman -S dkms android-tools

# Determine the current kernel
current_kernel=$(uname -r)
echo "Current kernel version is $current_kernel"

# Prompt the user to choose which kernel headers to install
echo "Which kernel headers do you want to install?"
echo "1. linux-headers"
echo "2. linux-lts-headers"
echo "3. linux-zen-headers"
echo "4. linux-xanmod-anbox-headers"
echo "5. linux-xanmod-headers"
echo "6. I have my headers already"
read -r -p "Enter your choice (1-6): " choice

case $choice in
    1)
        if pacman -Qs "linux-headers" > /dev/null ; then
            echo "linux-headers is already installed"
        else
          sudo pacman -S --noconfirm linux-headers
        fi
         sudo dkms install binder_linux/1.3.1 -k "$current_kernel"
         sudo dkms install ashmem_linux/1.3.1 -k "$current_kernel"
        ;;
    2)
        if pacman -Qs "linux-lts-headers" > /dev/null ; then
            echo "linux-lts-headers is already installed"
        else
           sudo pacman -S --noconfirm linux-lts-headers
        fi
       sudo dkms install binder_linux/1.3.1 -k "$current_kernel"
       sudo dkms install ashmem_linux/1.3.1 -k "$current_kernel"
        ;;
    3)
        if pacman -Qs "linux-zen-headers" > /dev/null ; then
            echo "linux-zen-headers is already installed"
        else
           sudo pacman -S --noconfirm linux-zen-headers
        fi
        ;;
    4)
        if pacman -Qs "linux-xanmod-anbox-headers" > /dev/null ; then
            echo "linux-xanmod-anbox-headers is already installed"
        else
            git clone https://aur.archlinux.org/linux-xanmod-anbox-headers.git
            cd linux-xanmod-anbox-headers || exit
            makepkg -cfsi
            cd ..
            sudo rm -rf linux-xanmod-headers
        fi
        ;;
    5)
        if pacman -Qs "linux-xanmod-headers" > /dev/null ; then
            echo "linux-xanmod-headers is already installed"
        else
            git clone https://aur.archlinux.org/linux-xanmod-headers.git
            cd linux-xanmod-headers || exit
            makepkg -cfsi
            cd ..
            sudo rm -rf linux-xanmod-headers
        fi
        ;;
    6)
        echo "Skipping headers..."
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

# Install Waydroid
echo "Installing Waydroid Waydroid Extra/Script and Waydroid Settings"

git clone https://aur.archlinux.org/waydroid-git.git
cd waydroid-git || exit
makepkg -cfsi
cd ..
sudo rm -rf waydroid-git

git clone https://aur.archlinux.org/waydroid-script-git.git
cd waydroid-script-git || exit
makepkg -cfsi
cd ..
sudo rm -rf waydroid-script-git

git clone https://aur.archlinux.org/waydroid-settings-git.git
cd waydroid-settings-git || exit
makepkg -cfsi
cd ..
sudo rm -rf waydroid-settings-git


# Run Waydroid init
echo "Do you want to run Waydroid init? (y/n)"
read -r run_init

if [[ $run_init =~ ^[Yy]$ ]]; then
    echo "Which version of Waydroid do you want to install? Vanilla(v) or GAPPS(g)"
    read -r waydroid_version
    if [[ $waydroid_version =~ ^[Gg]$ ]]; then
       sudo waydroid init -s GAPPS -f
    elif [[ $waydroid_version =~ ^[Vv]$ ]]; then
       sudo waydroid init -f
    else
       echo "Invalid option entered. Please enter 'v' for Vanilla or 'g' for GAPPS."
    fi
fi

# Ask user if they want to start and enable the waydroid-container.service
echo "Do you want to start and enable waydroid-container.service? (y/n)"
read -r start_service

if [[ $start_service =~ ^[Yy]$ ]]; then
    # Start and enable waydroid-container.service
    sudo systemctl start waydroid-container.service
    sudo systemctl enable waydroid-container.service
    echo "waydroid-container.service has been started and enabled."
else
    echo "waydroid-container.service has not been started or enabled."
fi

echo "Installation complete. Reboot the system to start using Waydroid."
