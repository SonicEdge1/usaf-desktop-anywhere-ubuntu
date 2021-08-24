#!/bin/bash

# NOT READY FOR USE!!

#references
# https://militarycac.com/chromebook.htm
# https://militarycac.org/linux.htm

echo "Making Certs Directory and downloading certs for chrome"
mkdir certs
cd certs
wget https://militarycac.com/maccerts/AllCerts.p7b
wget https://militarycac.com/maccerts/RootCert2.p7b
wget https://militarycac.com/maccerts/RootCert3.p7b
wget https://militarycac.com/maccerts/RootCert4.p7b
wget https://militarycac.com/maccerts/RootCert5.p7b

# assuming all the following are installed from DA script
#  not needed? ##pcsc-lite - PCSC Smart Cards Library
#  not needed? ##pcsc-ccid - generic USB CCID (Chip/Smart Card Interface Devices) driver
#  not needed? ##perl-pcsc - Abstraction layer to smart card readers
#  pcsc-tools - Optional but highly recommended, these tools are used to test a PCSC driver, card and reader


cd ~
modutil -dbdir sql:.pki/nssdb/ -add "CAC Module" -libfile /usr/lib/x86_64-linux-gnu/pkcs11/opensc-pkcs11.so


echo "Done"