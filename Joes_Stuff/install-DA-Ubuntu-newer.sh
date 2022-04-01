#!/bin/bash

# This script sets up the prerequisites and utilities needed to run Desktop anywhere on Ubuntu.
# The script is broken up into functions and has variables located at the top to make it more maintainable.
# The "Main" functions and order they are executed in is shown at the bottom of this file.

# message pace determines the pause between functions.  To run the script faster, decrease the message pace number
MESSAGE_PACE=4
DA_SERVER_ADDR=https://afrcdesktops.us.af.mil
CERT_DOWNLOAD_DIR=/usr/share/DOD_Certs_Download
DA_DIR=/usr/share/DesktopAnywhere_Download
CERT_SUB_DIR=Certificates_PKCS7_v5.9_DoD
CERT_ZIPFILE=certificates_pkcs7_DoD.zip 
CERT_DOWNLOAD_URL=https://dl.dod.cyber.mil/wp-content/uploads/pki-pke/zip/$CERT_ZIPFILE
VMWARE_FILE=VMware-Horizon-Client-5.5.2-18035020.x64.bundle
VMWARE_DOWNLOAD=https://download3.vmware.com/software/view/viewclients/CART21FQ3/$VMWARE_FILE
VMWARE_PKCS_DIR=/usr/lib/vmware/view/pkcs11
CERT_DIR=/usr/local/share/ca-certificates/dod/
DA_CERT_DIR=/usr/share/ca-certificates/
SMART_CARD_LIBRARY=/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so
SMART_CARD_LINK=/usr/lib/vmware/view/pkcs11/libopenscpkcs11.so
SYM_LINK_FOLDER=/usr/lib/vmware/view/pkcs11
LINK_TARGET=/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so
LINK_NAME=libopenscpkcs11.so
cert_install_required=false


# Function removes temporary directories used.  Typically executed when the script fails or at the very end.
cleanup () {
    echo -e "\n[INFO] Removing any temporary files and directories created...\n"; \
    rm -rv $CERT_DOWNLOAD_DIR
    rm -rv $DA_DIR
    echo -e "\n[INFO] Removed any temporary directories.\n"; \
}

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

# DEPENDENCIES:
# "tar" tar archiving utility
# "coreutils" GNU core utilities
# "wget" retrieves files from the web
# "libxkbfile1" X11 keyboard file manipulation library
# "libatk-bridge2.0-0" AT-SPI 2 toolkit bridge - shared library
# *Assistive Technology Service Provider Interface (AT-SPI) is a platform-neutral framework for providing bi-directional communication between assistive technologies (AT) and applications.
# "libxss1" Screen Saver extension library  MAYBE NOT NEEDED?
# "openssl" Secure Sockets Layer toolkit - cryptographic utility
# "unzip"  De-archiver for .zip files
# "libnss3-tools"  Network Security Service tools
# "libgtk-3-0" graphical user interface library REMOVED - NOT NEEDED ANYMORE

# Function checks for missing dependencies, and asks to install them if not detected.
check_dependencies() {
    echo -e "\n[INFO] Checking system for necessary dependencies..."; sleep $MESSAGE_PACE
    DEPS=("tar" "coreutils" "wget" "libxkbfile1" "libatk-bridge2.0-0" "libxss1" "openssl" "unzip" "libnss3-tools")
    MISSINGDEPS=()
    for i in "${DEPS[@]}"; do
    if ! dpkg-query -W -f='${Status}' "$i" 2>/dev/null | grep -q "ok installed"; then
        MISSINGDEPS+=("$i")
    else
        echo -e "$i installed"
    fi
    done
    if (( ${#MISSINGDEPS[@]} > 0 )); then
        echo -e "\n[INFO] Missing dependencies ${MISSINGDEPS[*]}..."
        if [[ "$1" == "-y" ]]; then
            echo -e "\n[INFO] Installing..."
            sudo apt update && sudo apt install -y ${MISSINGDEPS[*]};
        else
            read -rp "[INFO] Would you like to install them? [Y/n] ";
            if [[ $REPLY == [yY] ]]; then
                echo -e "\n[INFO] Installing..."
                sudo apt update && sudo apt install -y ${MISSINGDEPS[*]};
            else
                echo -e "\n[FAIL] Not installing dependencies; Exiting.\n" 1>&2;
                # exit 1;
            fi
        fi
    fi
    echo -e "\n[INFO] Dependencies resolved..."; sleep $MESSAGE_PACE
}

# Function installs programs needed to support smart card use.
# "opensc" Smart card utilities with support for PKCS#15 compatible cards 
# "opensc-pkcs11" Smart card utilities with support for PKCS#15 compatible cards
# "pcsc-tools" Some tools to use with smart cards and PC/SC
install_card_tools() {
	echo -e "\n[INFO] Installing opensc, opensc-pkcs11, pcsc-tools\...n"; sleep $MESSAGE_PACE;
	sudo apt install -y opensc opensc-pkcs11 pcsc-tools || \
        { echo -e "\n[FAIL] Failed to install necessary card tools!  Exiting." 1>&2; \
        exit 1; }
	echo -e "\n[INFO] Completed install of card reader tools...\n"; sleep $MESSAGE_PACE;
}

# Function checks to see if the desktop anywhere web gateway is accessable.  Sets the global variable cert_install_required based on results
check_if_gateway_accessible() {
{ echo -e "\n[INFO] Determining if Desktop Anywhere login gateway is accessible..." && sleep $MESSAGE_PACE && \
  wget -S --spider --timeout 20 $DA_SERVER_ADDR && \
  echo -e "\n[INFO] Desktop Anywhere login gateway is accessible..." && sleep $MESSAGE_PACE && \
  cert_install_required=false; } || \
{ echo -e "\n[INFO] Desktop Anywhere login gateway is not accessible; DoD certificate installation is required..."; sleep $MESSAGE_PACE;
  cert_install_required=true; };
}

# Function checks the gateway again using the check_if_gateway_accessible function.  Exits if gateway is not accessable after certificate installs.
check_gateway_again() {
    check_if_gateway_accessible
    if $cert_install_required; then
        echo -e "\n[FAIL] Failed to connect to the Desktop Anywhere login gateway after Certificate install!  Exiting." 1>&2
        exit 1
    fi
}

# Function downloads DOD certificates.  Exits if fails.
download_dod_certs() {
    { test -f $CERT_DOWNLOAD_DIR/$CERT_DOWNLOAD_URL || \
        { echo -e "\n[INFO] Downloading the DOD certificates...\n"; sleep $MESSAGE_PACE;
        ( mkdir -pv $CERT_DOWNLOAD_DIR && mkdir -pv $DA_DIR ) || \
            { echo -e "\n[FAIL] Directory creation failed!  Exiting." 1>&2; \
            cleanup; \
            exit 1; }
        wget -P $CERT_DOWNLOAD_DIR $CERT_DOWNLOAD_URL || \
            { echo -e "\n[FAIL] Certificate download did not complete!  Exiting." 1>&2; sleep $MESSAGE_PACE; \
            cleanup; \
            exit 1; }
        echo -e "\n[INFO] DOD certificate download complete...\n"; sleep $MESSAGE_PACE; } }
}

# Function unzips the DOD certificates zipfile that was downloaded. Exits if fails. 
unzip_dod_certs() {
    echo -e "\n[INFO] Unzipping DOD certificate download...\n"; sleep $MESSAGE_PACE;
    unzip $CERT_DOWNLOAD_DIR/$CERT_ZIPFILE -d $CERT_DOWNLOAD_DIR || \
        { echo -e "\n[FAIL] Failed to unzip certificate file!  Exiting." 1>&2; sleep $MESSAGE_PACE; \
        cleanup; \
        exit 1; }
    echo -e "\n[INFO] Certificates unzipped...\n"; sleep $MESSAGE_PACE;
}

## *NOT USING - NOT WORKING* ##
# Function is supposed to verify certificates are valid.  **see README file downloaded with certs.
verify_certificate_checksums() {  #Current source for certs does not work for verification **SEE README FILE Downloaded with certs
    { cd $CERT_DOWNLOAD_DIR/$CERT_SUB_DIR || { echo -e "\n[FAIL] Failed to cd into DoD certs sub-directory; Exiting." 1>&2; exit 1; } } && \
    { echo -e "\n[INFO] Verifying DoD certificate checksums..." && sleep $MESSAGE_PACE && \
      openssl smime -verify -in ./*.sha256 -inform DER -CAfile ./*.pem | \
      while IFS= read -r line; do
	  echo "${line%$'\r'}";
      done | \
      sha256sum -c; } || \
      { echo -e "\n[FAIL] File checksums do not match those listed in the checksum file; Exiting." 1>&2; \
        exit 1; }
}

## *NOT USING* replaced with convert_certificates_der##
# Function extracts and installs certificates from the downloaded p7b file
# converts p7b file into pem file and extracts certs
convert_certificates_pem() {
    { cd $CERT_DOWNLOAD_DIR/$CERT_SUB_DIR || \
        { pwd; echo -e "\n[FAIL] Failed to change to directory containing extracted certificates ($CERT_DOWNLOAD_DIR/$CERT_SUB_DIR); Exiting." 1>&2; exit 1; } }
    echo -e "\n[INFO] Creating DOD certificate sub-directory (${CERT_DIR})...\n"; sleep $MESSAGE_PACE;
    { mkdir -pv ${CERT_DIR} || \
        { echo -e "\n[FAIL] Failed to make dod sub-directory (${CERT_DIR}); Exiting." 1>&2; exit 1; } };
    echo -e "\n[INFO] Converting DoD certificates to plaintext format and staging for inclusion in system CA trust..." && sleep $MESSAGE_PACE;
    for p7b_file in *.pem.p7b; do
        pem_file="${p7b_file//.p7b/}"
        { echo -e "\n[INFO] Converting ${p7b_file} to ${pem_file}..." && \
          openssl \
              pkcs7 \
                  -in "${p7b_file}" \
                  -print_certs \
                  -out "${pem_file}";} || \
        { echo -e "\n[FAIL] Failed to convert ${p7b_file} to ${pem_file}; Exiting." 1>&2; \
          exit 1; } && \
	echo -e "\n[INFO] Splitting CA bundle file (${pem_file}) into individual cert files and staging for inclusion in system CA trust..." && sleep $MESSAGE_PACE && \
 	while read -r line; do
 	   if [[ "${line}" =~ END.*CERTIFICATE ]]; then
 	       cert_lines+=( "${line}" );
	       : > "${CERT_DIR}${individual_certs[ -1]}.crt";
 	       for cert_line in "${cert_lines[@]}"; do
 	           echo "${cert_line}" >> "${CERT_DIR}${individual_certs[ -1]}.crt";
               done;
 	       cert_lines=( );
 	   elif [[ "${line}" =~ ^[[:space:]]*subject=.* ]]; then
	       individual_certs+=( "${BASH_REMATCH[0]//*CN = /}" );
 	       cert_lines+=( "${line}" );
 	   elif [[ "${line}" =~ ^[[:space:]]*$ ]]; then
               :;
 	   else
 	       cert_lines+=( "${line}" );
 	   fi;
 	done < "${pem_file}";
    done;

    { cd - &>/dev/null || exit 1; } && \
    # echo -e "\n[INFO] Found a total of ${#individual_certs[@]} individual certs inside of CA bundles." && sleep $MESSAGE_PACE && \
    # Placing all individual_certs into a key in uniq_cert array to deduplicate non-unique certs
    # This assumes that CN values for all certs are sufficiently unique keys to act as UIDs
    declare -A uniq_certs && \
    for individual_cert in "${individual_certs[@]}"; do
        uniq_certs["$individual_cert"]="${individual_cert}";
    done && \
    echo -e "\n[INFO] Found a total of ${#uniq_certs[@]} unique certs inside of CA bundles..." && sleep $MESSAGE_PACE && \
    { echo -e "\n[INFO] The following DoD certificate files are staged for inclusion in the system CA trust:" && sleep $MESSAGE_PACE && \
      total_staged=0 && \
      for staged_file in ${CERT_DIR}*; do
        echo "${staged_file}";
	    total_staged="$((total_staged+1))";
      done; } && \
      echo "===END OF LIST===" && \
    # This ensures the user is aware if any certificates appear to have been left out entirely by accident
    # While a check is still performed at the end that Desktop Anywhere is accessible, this ensures other sites are too
    { if [[ "${total_staged}" != "${#uniq_certs[@]}" ]]; then
          echo -e "\n[FAIL] Failed to stage all previously discovered unique certificates." 1>&2;
	  exit 1;
      fi; };
}

# Function extracts and installs certificates from the downloaded p7b file
# converts p7b file into der file and extracts certs
convert_certificates_der() {
    ( mkdir -pv $CERT_DIR ) || \
    { echo -e "\n[FAIL] Directory creation failed!  Exiting." 1>&2; \
    # cleanup; \ no clean-up for this directory
    exit 1; }
    { cd $CERT_DOWNLOAD_DIR/$CERT_SUB_DIR || \
        { pwd; echo -e "\n[FAIL] Failed to change to directory containing extracted certificates ($CERT_DOWNLOAD_DIR/$CERT_SUB_DIR); Exiting." 1>&2; exit 1; } }
    for p7b_file in *.der.p7b; do
    der_file="${p7b_file//.p7b/}"
    { echo -e "\n[INFO] Converting ${p7b_file} to ${der_file}..." && \
        openssl \
            pkcs7 \
            -in "${p7b_file}" \
            -inform DER \
            -print_certs \
            -out "${der_file}"; } || \
        { echo -e "\n[FAIL] Failed to convert ${p7b_file} to ${der_file}; Exiting." 1>&2; \
        exit 1; };
	echo -e "\n[INFO] Splitting CA bundle file (${der_file}) into individual cert files and staging for inclusion in system CA trust..." && \
 	while read -r line; do
 	   if [[ "${line}" =~ END.*CERTIFICATE ]]; then
 	       cert_lines+=( "${line}" );
	        : > "${CERT_DIR}${individual_certs[ -1]}.crt"
 	       for cert_line in "${cert_lines[@]}"; do
 	           echo "${cert_line}" >> "${CERT_DIR}${individual_certs[ -1]}.crt";
               sleep $MESSAGE_PACE;
               done;
 	       cert_lines=( );
 	   elif [[ "${line}" =~ ^[[:space:]]*subject=.* ]]; then
	           individual_certs+=( "${BASH_REMATCH[0]//*CN = /}" );
 	           cert_lines+=( "${line}" );
 	   elif [[ "${line}" =~ ^[[:space:]]*$ ]]; then
               :;
 	   else
 	       cert_lines+=( "${line}" );
 	   fi;
 	done < "${der_file}";
    done
}

# Function adds all certificates to the system CA trust
install_certificates_auto() {
    { echo -e "\n[INFO] Adding staged DoD certificates (and any other previously staged certs) to system CA trust..." && sleep $MESSAGE_PACE && \
      update-ca-certificates --verbose && \
      echo -e "\n[INFO] Successfully added staged certificates to system CA trust..." && sleep $MESSAGE_PACE; } || \
    { echo -e "\n[FAIL] Failed to add staged certificates to system CA trust; Exiting." 1>&2; \
      exit 1;};
}

## Unused ##
# Function gets rid of spaces that exist in the filename
get_rid_of_spaces_in_fileNames(){
    for f in *\ *; do mv "$f" "${f// /_}"; done
}

## Unused - replaced with install_certificates_auto ##
# Function pulls up a GUI to walk the user through adding the DOD Certificates to the system CA trust
install_certificates_manual() {
    echo -e "\n[INFO] Installing DOD Certificates...\n"; sleep $MESSAGE_PACE;
    zenity --info --text '<span foreground="black" font="24">Instructions: \
    \nIn the pop-up GUI, use arrow keys to select Ask, then press tab to select &lt;OK&gt; \
    \nOn the next screen, make sure asterisks are present next to DOD certs and select &lt;OK&gt;</span> \
    \n\n\n\n<i>(pressing the OK button closes this information window)</i>' --width=700 --height=300 &
    sudo dpkg-reconfigure ca-certificates || \
        { echo -e "\n[FAIL] Failed to install DOD certificates!  Exiting." 1>&2; \
        exit 1; }
}

# Function installs VMware Horizion Client and sets preferences
# Reference Documentation: https://docs.vmware.com/en/VMware-Horizon-Client-for-Linux/5.4/horizon-client-linux-installation/GUID-A5A6332F-1DEC-4D77-BD6E-1362596A2E76.html
install_vmware() {
    echo -e "\n[INFO] Checking if VMWare Horizon client is already installed..."; sleep $MESSAGE_PACE;
    if hash vmware-view 2>/dev/null; then
        echo -e "\n[INFO] VMWare Horizon client is already installed; skipping installation..."; sleep $MESSAGE_PACE;
    else
        echo -e "\n[INFO] VMWare Horizon client is not already installed; installing..."; sleep $MESSAGE_PACE;
        { test -f $DA_DIR/$VMWARE_FILE || \
            { echo -e "\n[INFO] Downloading VMware Horizon Client for 64-bit Linux..."; sleep $MESSAGE_PACE;
            wget -P $DA_DIR $VMWARE_DOWNLOAD || \
                { echo -e "\n[FAIL] VMware Horizon Client download did not complete!  Exiting." 1>&2; \
                exit 1; }
            echo -e "\n[INFO] VMware Horizon Client download successful.  Proceeding with Install..."; sleep $MESSAGE_PACE; } }
        { cd $DA_DIR || \
            { pwd; echo -e "\n[FAIL] Failed to change to directory containing VMware Download ($DA_DIR); Exiting." 1>&2; exit 1; } }
        chmod +x $VMWARE_FILE
        sudo env TERM=dumb VMWARE_EULAS_AGREED=yes \
        ./$VMWARE_FILE --console \
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
            echo -e "\n[INFO] Successfully installed VMware Horizon client..."; sleep $MESSAGE_PACE;
        else
            echo -e "\n[FAIL] Failed to install VMWare Horizon client." 1>&2;
            exit 1;
        fi;       
    fi;
}

# Function creates a symbolic link that is vital for the VMware to so it finds the DOD certificates
create_symbolic_link_to_OpenSC_module() {
    echo -e "\n[INFO] Creating symbolic link to OpenSC module..."; sleep $MESSAGE_PACE;
    { mkdir -v ${SYM_LINK_FOLDER} || \
        { echo -e "\n[FAIL] Failed to make symbolic link directory (${SYM_LINK_FOLDER}); Exiting." 1>&2; exit 1; } };
    { sudo ln -s $LINK_TARGET $SYM_LINK_FOLDER/$LINK_NAME || \
        { echo -e "\n[FAIL] Failed to create required symbolic link; Exiting."; 1>&2; exit 1; } };
    echo -e "\n[INFO] Successfully created symbolic link to OpenSC module..."; sleep $MESSAGE_PACE;
}

# Function displays a pop-up message that displays the servers avavilable for logging into NIPPR DA
install_complete() {
    echo -e "\n[INFO] Ubuntu is now ready to run the VMware Horizon Client (Desktop Anywhere).\n"; sleep $MESSAGE_PACE;
    zenity --info --text '<span foreground="black" font="24">Instructions: \
    \nThere are currently 4 servers that have been allocated for our use. \
    \nUse the "New Server" button in the VMware Horizon Client to add each of the following: \
    \nuhhz-ss-001v.us.af.mil \
    \nuhhz-ss-002v.us.af.mil \
    \nuhhz-ss-003v.us.af.mil \
    \nhttps://afrcdesktops.us.af.mil </span> \
    \n\n\n\n<i>(pressing the OK button closes this information window)</i>' --width=700 --height=300 &
}

# Function usses several helper functions to walk through all the steps of installing DOD certificates
install_cert_steps() {
    if $cert_install_required; then
        download_dod_certs
        unzip_dod_certs
        # verify_certificate_checksums #(fails.. bad function? or expired certs?)
        convert_certificates_der
        install_certificates_auto
    fi
}

# Following is the "main" set of functions used to install Desktop Anywhere (DA)
check_if_root
check_dependencies #My Ubuntu install contained everything neeeded. Minimal install could be different.
install_card_tools
check_if_gateway_accessible
install_cert_steps #uses several helper functions
check_gateway_again
install_vmware
create_symbolic_link_to_OpenSC_module
cleanup
install_complete
echo DONE

