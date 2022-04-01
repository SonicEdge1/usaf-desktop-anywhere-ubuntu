#!/bin/bash

# This script will disconnect your openVPN connection using your configuration profile name

PROFILE_NAME=your_profile_name_goes_here
openvpn3 session-manage --config $PROFILE_NAME --disconnect
