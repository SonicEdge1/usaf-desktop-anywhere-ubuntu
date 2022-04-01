#!/bin/bash

# Script file saves a persistent vpn config file to be used in the future

OVPN_FILE=your_ovpn_file_goes_here.ovpn

openvpn3 config-import --config $OVPN_FILE --persistent

echo "Done"
