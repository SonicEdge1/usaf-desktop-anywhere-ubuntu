#!/bin/bash

# This script will install OpenVPN client on to an Ubuntu / Debian system.

# Change the DISTRO variable to match your Ubuntu version
# Debian 9 = stretch
# Debian 10 = buster
# Ubuntu 16.04 = xenial
# Ubuntu 18.04 = bionic
# Ubuntu 20.04 = focal
# Ubuntu 20.10 = groovy
# Ubuntu 21.04 = hirsute 

DISTRO=focal

sudo apt install apt-transport-https
sudo wget https://swupdate.openvpn.net/repos/openvpn-repo-pkg-key.pub
sudo apt-key add openvpn-repo-pkg-key.pub
sudo wget -O /etc/apt/sources.list.d/openvpn3.list https://swupdate.openvpn.net/community/openvpn3/repos/openvpn3-$DISTRO.list
sudo apt update
sudo apt apt install openvpn3
echo "Done"
