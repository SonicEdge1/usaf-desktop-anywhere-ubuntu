#!/bin/bash

# Sometimes older versions of the VMware Horizon Client are not supported anymore in the AFRC Desktop Anywhere environment.
# This script will update the VMware Horizon Client version.
# It requires that the Old VMware .bundle file used to install the client is present in the DA_DIR directory.
# It also requires that the NEW_VMWARE_FILE variable be updated to the newer .bundle file version desired.
# Current versions can be found at the following URL:
# https://customerconnect.vmware.com/en/downloads/info/slug/desktop_end_user_computing/vmware_horizon_clients/horizon_8
# Select a VMware Horizon Client bundle installer for 64-bit Linux, and go to the dowloads page.
# Copy the link address from the download button and update the NEW_VMWARE_FILE and VMWARE_DOWNLOAD variables appropriately.

MESSAGE_PACE=3
DA_DIR=/usr/share/DesktopAnywhere_Download
OLD_VMWARE_FILE=empty.bundle
NEW_VMWARE_FILE=VMware-Horizon-Client-2312-8.12.0-23149323.x64.bundle
VMWARE_DOWNLOAD=https://download3.vmware.com/software/CART23FQ2_LIN64_2206/$NEW_VMWARE_FILE
PRODUCT='VMware Horizon Client'

# Function checks to see if the script is being executed with sudo privileges.  Exits if not.
check_if_root() {
    echo -e "\n[INFO] Checking effective user id..."; sleep $MESSAGE_PACE
    if [[ $EUID -ne 0 ]]; then
        echo -e "\n[FAIL] Script must be run with sudo or as root; Exiting." 1>&2;
        exit 1;
    else
        echo -e "\n[INFO] Effective user id is zero (i.e. root or sudo user); proceeding with install...\n"; sleep $MESSAGE_PACE;
    fi
}

get_confirmation() {
    read -p "WARNING! Execution of this script will REMOVE the current version of the $PRODUCT from the system.\
    It will then proceed to install $NEW_VMWARE_FILE  Do you wish to continue?? (Y/N): " response

    # Check if the response is affirmative
    if [[ "$response" =~ ^[Yy](es)?$ ]]; then
        echo -e "\n[INFO] Proceeding with $PRODUCT upgrade...";
    else
        echo -e "\n[INFO] $PRODUCT upgrade has been aborted.";
        exit 1;
    fi
}

remove_vmware() {
    echo -e "\n[INFO] Checking if $PRODUCT is already installed..."; sleep $MESSAGE_PACE;
    if hash vmware-view 2>/dev/null; then
    # proceede with uninstall
        echo -e "\n[INFO] $PRODUCT is installed; starting removal..."; sleep $MESSAGE_PACE;
        # find old bundle file
        echo -e "\n[INFO] Searching for old $PRODUCT .bundle file..."; sleep $MESSAGE_PACE;
        OLD_VMWARE_FILE=$(find "$DA_DIR" -type f -name "VMware*.bundle" -print -quit)

        # Check if FILE is empty (no matching file found)
        if [ -z "$OLD_VMWARE_FILE" ]; then
            echo -e "[FAIL] No VMware bundle file found in $DA_DIR." 1>&2;
            exit 1;
        else
            echo -e "\n[INFO] VMware .bundle file found: $OLD_VMWARE_FILE";
            echo -e "\n[INFO] $PRODUCT is installed; starting removal..."; sleep $MESSAGE_PACE;
            # sudo env VMWARE_KEEP_CONFIG=yes ./$OLD_VMWARE_FILE -u vmware-horizon-client;
             cat $OLD_VMWARE_FILE;

        fi
    else
    #exit here
        echo -e "\n[FAIL] $PRODUCT is not already installed; nothing to remove." 1>&2;
        exit 1;
    fi
}

delete_old_file() {
    read -p "If the uninstall was successfull, it is recommended that you delete the old VMware .bundle file.\
    Do you want to delete the old WMware bundle file: $OLD_VMWARE_FILE? (Y/N): " response

    # Check if the response is affirmative
    if [[ "$response" =~ ^[Yy](es)?$ ]]; then
        # Check if the file exists before attempting to delete it
        if [ -f "$OLD_VMWARE_FILE" ]; then
            # Delete the file
            sudo rm $OLD_VMWARE_FILE
            echo -e "\n[INFO] File $OLD_VMWARE_FILE has been deleted."
        else
            echo -e "\n[FAIL] File $OLD_VMWARE_FILE does not exist." 1>&2;
        fi
    else
        echo -e "\n[INFO] File deletion aborted."
    fi
}

install_vmware() {
    echo -e "\n[INFO] Checking if $PRODUCT is already installed..."; sleep $MESSAGE_PACE;
    if hash vmware-view 2>/dev/null; then
        echo -e "\n[INFO] $PRODUCT is already installed; skipping installation..."; sleep $MESSAGE_PACE;
    else
        echo -e "\n[INFO] $PRODUCT is not already installed; installing..."; sleep $MESSAGE_PACE;
        { test -f $DA_DIR/$NEW_VMWARE_FILE || \
            { echo -e "\n[INFO] Downloading $PRODUCT for 64-bit Linux..."; sleep $MESSAGE_PACE;
            wget -P $DA_DIR $VMWARE_DOWNLOAD || \
                { echo -e "\n[FAIL] $PRODUCT download did not complete!  Exiting." 1>&2; \
                exit 1; }
            echo -e "\n[INFO] $PRODUCT download successful.  Proceeding with Install..."; sleep $MESSAGE_PACE; } }
        { cd $DA_DIR || \
            { pwd; echo -e "\n[FAIL] Failed to change to directory containing VMware Download ($DA_DIR); Exiting." 1>&2; exit 1; } }
        chmod +x $NEW_VMWARE_FILE
        sudo env TERM=dumb VMWARE_EULAS_AGREED=yes \
        ./$NEW_VMWARE_FILE --console \
        --set-setting vmware-horizon-html5mmr html5mmrEnable yes \
        --set-setting vmware-horizon-integrated-printing vmipEnable yes \
        --set-setting vmware-horizon-media-provider mediaproviderEnable yes \
        --set-setting vmware-horizon-mmr mmrEnable no \
        --set-setting vmware-horizon-rtav rtavEnable yes \
        --set-setting vmware-horizon-scannerclient scannerEnable yes \
        --set-setting vmware-horizon-serialportclient serialportEnable yes \
        --set-setting vmware-horizon-smartcard smartcardEnable yes \
        --set-setting vmware-horizon-tsdr tsdrEnable yes \
        --set-setting vmware-horizon-usb usbEnable yes \
        --set-setting vmware-horizon-virtual-printing tpEnable yes;
        if hash vmware-view 2>/dev/null; then
            echo -e "\n[INFO] Successfully installed $PRODUCT..."; sleep $MESSAGE_PACE;
        else
            echo -e "\n[FAIL] Failed to install $PRODUCT." 1>&2;
            exit 1;
        fi;       
    fi;
}

check_if_root
get_confirmation
remove_vmware
delete_old_file
install_vmware
echo DONE