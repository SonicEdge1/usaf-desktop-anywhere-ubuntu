#!/bin/bash

# GENERAL INFORMATION #
# This script was written to provide an easy way to enable a Debian based OS to sign git commits using a 
# Tested on Ubuntu 20.04
# CAC or GPG signing is now required by Platform1 when commiting code at IL4 or above.
# References:
# GPG: https://confluence.il2.dso.mil/display/P1MDOHD/HowTo+-+GitLab+-+Code+Signing+with+GPG
# CAC: https://confluence.il2.dso.mil/display/P1MDOHD/HowTo+-+GitLab+-+Code+Signing+with+CAC#HowToGitLabCodeSigningwithCAC-LINUX

# PREREQUISITES #
# go to GitLab's User Settings > Profile and change the commit email to the (newly-added/verified) CAC CDS-associated email address. 
# neet to have wget installed

# VARIABLES #
# message pace determines the pause between functions.  To run the script faster, decrease the message pace number
MESSAGE_PACE=2
TEST_FILE=$(pwd)/test.file
CONFIG_FILE_A=~/.gnupg/gnupg-pkcs11-scd.conf
CONFIG_FILE_B=~/.gnupg/gpg-agent.conf
CERT_FILE=unclass-certificates_pkcs7_v5-6_dod.zip
CERT_FOLDER=Certificates_PKCS7_v5.6_DoD
MY_CERT_FILE=mycert.crt
FILE_B_CONTENTS="scdaemon-program /usr/bin/gnupg-pkcs11-scd"
RM_FILEA="DODEMAILCA_59.cer"

read -r -d '' FILE_A_CONTENTS << EOM
nproviders p1
nprovider-p1-library /usr/lib/pkcs11/libcoolkeypk11.so
nproviders smartcardhsm
nprovider-smartcardhsm-library /usr/lib/x86_64-linux-gnu/opensc-pkcs11.so
EOM

# FUNCTIONS #

# Function removes all downloaded content from this script
cleanup() {
  sudo rm -f $MY_CERT_FILE
  sudo rm -f $RM_FILEA
  sudo rm -f $CERT_FILE
  sudo rm -rf $CERT_FOLDER
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

# Function displays a pop-up message to remind users that they need their CAC card inserted
cac_reminder() {
    echo -e "\n[INFO] Please insert your CAC card before porceeding."; sleep $MESSAGE_PACE;
    zenity --info --text '<span foreground="black" font="24">Note: \
    \nYour CAC card must be inserted to proceed.</span> \
    \n\n\n\n<i>(pressing the OK button closes this information window)</i>' --width=700 --height=300 &
    BACK_PID=$!
    echo "[INFO] Waiting for acknowledgement of message. Please click OK (PID $BACK_PID)"
    wait $BACK_PID
}

# Function installs programs needed to support smart card use.
# "libpcsclite1" Middleware to access a smart card using PC/SC (library)
# "pcscd" Middleware to access a smart card using PC/SC (daemon side)
# "pcsc-tools" Some tools to use with smart cards and PC/SC
install_card_middleware() {
	echo -e "\n[INFO] Installing libpcsclite1 pcscd pcsc-tools...\n"; sleep $MESSAGE_PACE;
	sudo apt install -y libpcsclite1 pcscd pcsc-tools || \
        { echo -e "\n[FAIL] Failed to install necessary card middleware!  Exiting." 1>&2; \
        exit 1; }
	echo -e "\n[INFO] Completed install of card middleware...\n"; sleep $MESSAGE_PACE;
}

# Function enables the use of your CAC card/smart card reader
enable_pcscd() {
	echo -e "\n[INFO] Enabling pcscd...\n"; sleep $MESSAGE_PACE;
	sudo systemctl enable pcscd --now || \
        { echo -e "\n[FAIL] Failed to enable pcscd!  Exiting." 1>&2; \
        exit 1; }
	echo -e "\n[INFO] pcscd enabled...\n"; sleep $MESSAGE_PACE;
}

# checking that pcsc_scan works would be part of the process here, but the program
# doesn't necessarily exit on its own unless just listing card readers. may not be able to test.

# Install the gpg and smart card utilities
# "gpg" GNU Privacy Guard -- minimalist public key operations
# "dirmngr" GNU privacy guard - network certificate management service
# "gnupg2" GNU privacy guard - a free PGP replacement (dummy transitional package)
# "coolkey" Smart Card PKCS #11 cryptographic module
# "gnupg-pkcs11-scd" GnuPG smart-card daemon with PKCS#11 support
# "opensc" Smart card utilities with support for PKCS#15 compatible cards
install_card_utilities() {
	echo -e "\n[INFO] Installing gpg coolkey dirmngr gnupg2 gnupg-pkcs11-scd opensc\...n"; sleep $MESSAGE_PACE;
	sudo apt install -y gpg coolkey dirmngr gnupg2 gnupg-pkcs11-scd opensc || \
        { echo -e "\n[FAIL] Failed to install necessary card utilities!  Exiting." 1>&2; \
        exit 1; }
	echo -e "\n[INFO] Completed install of card utilities...\n"; sleep $MESSAGE_PACE;
}

# Function checks initial output of gpgconf to ensure it meets expectations
check_gpgconf_config() {
  echo -e "\n[INFO] Checking initial gpgconf configuration\...n"; sleep $MESSAGE_PACE;
  result="$(gpgconf)"
  read -r -d '' expected << EOM
gpg:OpenPGP:/usr/bin/gpg
gpg-agent:Private Keys:/usr/bin/gpg-agent
scdaemon:Smartcards:/usr/lib/gnupg/scdaemon
gpgsm:S/MIME:/usr/bin/gpgsm
dirmngr:Network:/usr/bin/dirmngr
pinentry:Passphrase Entry:/usr/bin/pinentry
EOM
  echo -e "result: \n\
$result"
  if [[ $result =~ $expected ]]; then
    echo -e "\n[INFO] initial run of gpgconf is good...\n"; sleep $MESSAGE_PACE;
  else
    { echo -e "\n[FAIL] Failed to get correct response from gpgconf!\
    \nexpected:\
    \n$expected\
    \nExiting.";
    exit 1;}
  fi
}

# Function writes given contents to a given file
# $1 file to write to
# $2 file contents
put_contents_in_file() {
	echo -e "\n[INFO] Writing to file $1\...n"; sleep $MESSAGE_PACE;
	echo "$2" >> $1 || \
        { echo -e "\n[FAIL] Failed to write to file! $1  Exiting." 1>&2; \
        exit 1; }
	echo -e "\n[INFO] Completed writing to $1...\n"; sleep $MESSAGE_PACE;
}

# Function checks if file exists.  If file does not exist,
# the put_contents_in_file function is called,
# otherwise the function completes.
# Parameter $1 is the file
# Parameter $2 are the file contents
write_to_file_if_not_exist() {
  test -f $1 \
    && (
      echo -e "\n[INFO] File $1 exists."; \
      echo "[INFO] ***Skipping file write..."; sleep $MESSAGE_PACE;) \
    || (
        (
          echo -e "\n[INFO] File $1 NOT FOUND" && \
          echo "[INFO] Creating and writing contents" && \
          put_contents_in_file $1 "$2" || (exit 1;)
        )
    )
}


# Function that sets up the command line interface for entering the CAC pin
use_cli_for_pin() {
  echo -e "\n[INFO] configuring cli for pin entry...\n"; sleep $MESSAGE_PACE;
  (
    echo 'pinentry-program /usr/local/bin/pinentry-curses' >> ~/.gnupg/gpg-agent.conf && \
    echo  'export GPG_TTY=$(tty)' >> ~/.bashrc
  ) || {
    echo -e "\n[FAIL] Failed to set up cli for pin entry!  NOT Critical, Continuing." 1>&2; \
  }
  echo -e "\n[INFO] Completed cli pin entry configuration...\n"; sleep $MESSAGE_PACE;
}


# function downloads necessary certificate file
get_cert_zip_file() {
	echo -e "\n[INFO] Downloading and unzipping security certificates...\n"; sleep $MESSAGE_PACE;
	(wget https://dl.dod.cyber.mil/wp-content/uploads/pki-pke/zip/$CERT_FILE && unzip $CERT_FILE) || \
        { echo -e "\n[FAIL] Failed to download or unzip necessary certificates!  Exiting." 1>&2; \
        cleanup; exit 1; }
	echo -e "\n[INFO] Completed download...\n"; sleep $MESSAGE_PACE;
}


# Function adds DoD Root Certificate 3 to your systems root trust store
place_certs_in_trust_store() {
	echo -e "\n[INFO] Placing certificates into root trust store...\n"; sleep $MESSAGE_PACE;
	(
    sudo cp $CERT_FOLDER/DoD_PKE_CA_chain.pem /usr/local/share/ca-certificates/DoD_PKE_CA_chain.crt && \
    sudo cp $CERT_FOLDER/DoD_PKE_CA_chain.pem /etc/ssl/certs/DoD_PKE_CA_chain.crt && \
    sudo update-ca-certificates) \
    || \
        { echo -e "\n[FAIL] Failed to place certificates into root trust store!  Exiting." 1>&2; \
        cleanup; exit 1; }
	echo -e "\n[INFO] Success! Certificates placed in root trust store...\n"; sleep $MESSAGE_PACE;
}

# Function extracts single cert file
extract_cert() {
  echo -e "\n[INFO] Extracting certificate...\n"; sleep $MESSAGE_PACE;
  (
  sudo pkcs15-tool --read-certificate $1 > $MY_CERT_FILE && \
  cat $MY_CERT_FILE &&  \
  wget $(openssl x509 -in $MY_CERT_FILE -text | grep "CA Issuers" | awk '{ print $4 }' | sed 's/URI://g') \
  ) || { \
    echo -e "\n[FAIL] Failed to Extract Certificate for Digital Signature!  Exiting." 1>&2; \
    cleanup; exit 1; }
  echo -e "\n[INFO] Successfully verified and extracted Certificate for Digital Signature...\n"; sleep $MESSAGE_PACE;
}

# Function examines output from pkcs15-tool command and determines certificate used for digital signature
# asks user to verify number
verify_certificate_num() {
  
  echo -e "\n[INFO] Verifying signature certificate number...\n"; sleep $MESSAGE_PACE;
	(
    cert_list=$(pkcs15-tool --list-certificates) && \
    echo -e "CERT_LIST: $cert_list\n" && \
    parsed_certID=$(echo "$cert_list" | awk '/Signature/{flag=1;next}/Encoded/{flag=0}flag' | awk '/ID/{print $3}') && \
    read -p "[!!INPUT!!] Verify the ID of X.509 Certificate [Certificate for Digital Signature] in readout above [Default:$parsed_certID]: " certID && \
    certID=${certID:-$parsed_certID} &&\
    echo "[INFO] Using ID: $certID" && \
    extract_cert $certID \
  ) || { \
    echo -e "\n[FAIL] Failed to verify Certificate for Digital Signature!  Exiting." 1>&2; \
    cleanup; exit 1; }
}

# Function imports the Root CRL and updates config files for GnuPG system
import_root_CRL() {
  echo -e "\n[INFO] Importing the Root CRL and updating configuration of GnuPG system...\n"; sleep $MESSAGE_PACE;
  (
    touch ~/.gnupg/trustlist.txt && \
    default_cer_file="DODEMAILCA_59.cer" && \
    read -p "[!!INPUT!!] Verify the saved file name above i.e. Saving to: ‘DODEMAILCA_59.cer’ in readout above [Default:$default_cer_file]: " cer_file && \
    cer_file=${cer_file:-$default_cer_file} && \
    dirmngr --fetch-crl $(openssl x509 -inform der -in $cer_file -text | grep crl | grep -v "CA Issuers" | sed 's/URI://g') && \
    gpgsm --import $cer_file && \
    gpgsm --import $MY_CERT_FILE && \
    RM_FILEA=$cer_file \
  ) || { \
    echo -e "\n[FAIL] Failed to import the Root CRL or update configuration of GnuPG system!  Exiting." 1>&2; \
    cleanup; exit 1; }
  echo -e "\n[INFO] Successfully imported the Root CRL and updated configuration of GnuPG system...\n"; sleep $MESSAGE_PACE;
}

# Function terminates gpg agent allowing restart
restart_GPG_agent() {
  echo -e "\n[INFO] Restarting GPG agent to use new settings...\n"; sleep $MESSAGE_PACE;
  gpgconf --kill all || { echo -e "\n[FAIL] Failed to Restart GPG agent!  Exiting." 1>&2; \
    cleanup; exit 1; }
}



# Function displays popup telling users how to set up git config for gpg signing
note() {
  read -r -d '' FILE_A_CONTENTS << EOM
    \nsigningEmail=\$(gpgsm --list-secret-keys | grep aka |  awk '{ print \$2 }')
    \nsigningkey=\$( gpgsm --list-secret-keys | egrep '(key usage|ID)' | grep -B 1 digitalSignature | awk '/ID/ {print \$2}')
    \ngit config user.email \$signingEmail
    \ngit config user.signingkey \$signingkey
    \ngit config gpg.format x509
    \ngit config gpg.x509.program gpgsm
    \ngit config commit.gpgsign true
EOM
    zenity --info --width=800 --height=300 --text="Run the following commands in the terminal if you wish to set up git gpg signing globally: \
    \n\n $FILE_A_CONTENTS"
}

# Function updates git configs for gpg signing
add_git_gpg_sign() {
  echo -e "\n[INFO] Configuring git for gpg signing...\n"; sleep $MESSAGE_PACE;
  (
    signingEmail=$(gpgsm --list-secret-keys | grep aka |  awk '{ print $2 }') && \
    signingkey=$( gpgsm --list-secret-keys | egrep '(key usage|ID)' | grep -B 1 digitalSignature | awk '/ID/ {print $2}') && \
    git config user.email $signingEmail && \
    git config user.signingkey $signingkey && \
    git config gpg.format x509 && \
    git config gpg.x509.program gpgsm && \
    git config commit.gpgsign true \
  ) || { \
  { echo -e "\n[FAIL] Failed to configure git!  Exiting." 1>&2; \
    exit 1; }
  }
  echo -e "\n[INFO] Completed git configuration for gpg signing...\n"; sleep $MESSAGE_PACE;
}

# Function asks if user wants to perfom a function, and responds appropriately
# $1 message of action to be performed
# $2 function to perform
ask_and_run_function() {
  read -rp "[INFO] Would you like to $1 ? [Y/n] ";
  if [[ $REPLY == [yY] ]]; then
      $2;
  else
      echo -e "\n[INFO] Skipping $1.\n"; sleep $MESSAGE_PACE;
      note
  fi
}

############################################
# MAIN #
# Following is the "main" set of functions

# check_if_root
cac_reminder
install_card_middleware
install_card_utilities
write_to_file_if_not_exist $CONFIG_FILE_A "$FILE_A_CONTENTS"
write_to_file_if_not_exist $CONFIG_FILE_B "$FILE_B_CONTENTS"
ask_and_run_function "use the command line interface to enter your pin instead of a pop-up window?" use_cli_for_pin
get_cert_zip_file
unzip_cert_zip_file
verify_certificate_num
import_root_CRL
restart_GPG_agent
cleanup
ask_and_run_function "set up git for gpg signing (this repo only)" add_git_gpg_sign
echo "DONE"

# First Commit:
# Your first attempt at signing a commit may fail if the Root CA is not already trusted.
# You will be prompted to trust (and later confirm) the DoD Root CA with a similar message as below. Elect to trust the certificate and its fingerprint will then be added to ~/.gnupg/trustlist.txt.
# Once that is done, reattempting the commit should work.

# Commit Troubleshooting:
# If you are having any issues with the gpg agent, aside from rebooting or re-inserting your CAC card, you can run this command to kill the gpg-agent server
# gpgconf --kill all
#
# Additionally, if using a pin entry program other than the GUI (i.e. pinentry-curses), it may take a few tries to sign a commit.  You can run this command, which is more time-friendly, in order to get the initial pin entry and certificate trust prompts squared away:
# gpgsm --status-fd=2 -bsau $signingkey
#
# Previous unsigned commits in a branch could be hampering the ability to create new commits.  Use:
# git restore --staged .
# Then try to commit again (git commit -S -m 'your message')

# Push Troubleshooting:
# Push could be failing due to mixed signed and unsigned commits
# reset, to my previous good push.
# Get the SHA from that push, then do
# git reset --soft <SHA>  Which “un-did” commits.
# Do a successful signed commit.
# And then push.