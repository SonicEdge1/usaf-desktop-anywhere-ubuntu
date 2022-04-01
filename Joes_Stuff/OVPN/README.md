# Setting up and Using Open VPN

## Included Files:
* ovpn_install_for_Ubuntu.sh - Installs the open vpn client on an Ubuntu OS
* import_config_file.sh - Imports the config file for persistent future use as a config profile
* connect.sh - Connects to the VPN using the stored configuration profile
* disconnect.sh - Disconnects from the VPN using the stored config profile

## Instructions:
All files need to be modified in order to work properly.

### ovpn_install_for_Ubuntu.sh
* The DISTRO variable needs changed to appropriately match your version of Ubuntu (see instructions in file
)

### import_config_file.sh
* The OVPN_FILE variable needs to be changed to the location/file.ovpn that was sent to you by the system admin.

### connect.sh
* The PROFILE_NAME variable needs to be changed to the name of the VPN profile you want to use.  
If you have run the import script, you can find your profile name by typing:  
`openvpn3 configs-list`  
Your configuration profile name it will be the last returned line

### disconnect.sh
* The PROFILE_NAME variable needs to be changed to the name of the VPN profile you want to disconnect from.

## Sources:
* https://community.openvpn.net/openvpn/wiki/OpenVPN3Linux
* https://openvpn.net/cloud-docs/openvpn-3-client-for-linux/
* https://openvpn.net/vpn-server-resources/connecting-to-access-server-with-linux/