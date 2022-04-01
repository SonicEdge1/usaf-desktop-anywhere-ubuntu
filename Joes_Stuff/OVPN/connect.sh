#!/bin/bash

# This script connects you to the vpn using a persisted configuration profile name
# If you have run the import script, you can find your profile name by typing:
# openvpn3 configs-list
# it will be the last returned line

PROFILE_NAME=your_profile_name_goes_here

openvpn3 session-start --config $PROFILE_NAME
