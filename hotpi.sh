#!/bin/bash

#pispot installation script
###########################
#
#Installs the pispot system
#
###########################


#user configuration options

#network details for the wireless network adaptor
IP4_INT=wlan0
IP4_CONF_TYPE=static
IP4_ADDRESS=192.168.2.1
IP4_NETMASK=255.255.255.0

IP4_NETWORK=${IP4_ADDRESS%?}0
IP4_BROADCAST=${IP4_ADDRESS%?}255
IP4_GATEWAY=${IP4_ADDRESS}

#dhcp server configuration details
IP4_DNS1=8.8.8.8.8
IP4_DNS2=4.4.4.4
IP4_STARTADDRESS=${IP4_ADDRESS%?}2
IP4_ENDADDRESS=${IP4_ADDRESS%?}50


GREEN='\e[00;32m'
DEFT='\e[00m'
RED='\e[00;31m'
YELLOW='\e[00;33m'

function checkfileExists {
#echo $1
if [ ! -f ./$1 ]; then
    #echo "File not found!"
	return 1
else
        #echo "fILE FOUND"
	return 0
fi
}

function checkInternet {
wget -q --tries=3 --timeout=5 http://google.com > /dev/null
if [[ ! $? -eq 1 ]]; then
	return 0
fi
}

#check current user privileges
#  (( `id -u` )) && echo -e "${RED}This script MUST be ran with root privileges, try prefixing with sudo. i.e sudo $0" && exit 1


clear

#check for hostapd

function installPackage {
echo -e "${DEFT}First, lets see if the "$1" packages are installed...\n"

dpkg -l $1 | grep ^ii > /dev/null 2>&1
INSTALLED=$?

if [ $INSTALLED == '0' ]; then
        echo -e "${GREEN}$1 is installed...moving on\n"
    else
        echo -e "${RED}"$1" is not installed...will install now\n"
	    
	if checkfileExists $1*;then
		echo -e "${DEFT}Installing locally"
		dpkg -i $1*
	else
		echo -e "${DEFT}No local copy found...trying for install from the repo's"

		if checkInternet; then
        		echo -e "${RED}Internet not reachable"
		       exit 1
		else
			echo "Installing from repos"
			apt-get install $1
		fi
fi
fi

}
installPackage hostapd
installPackage isc-dhcp-server

#installed, so now for configuration


#set up the wlan interface
echo "iface $IP4_INT inet $IP4_CONF_TYPE
    address $IP4_ADDRESS
    netmask $IP4_NETMASK
    broadcast $IP4_BROADCAST
    gateway $IP4_GATEWAY">>/etc/network/interfaces

#set up hostapd configuration

cp /etc/hostapd/hostapd.conf hostapd.conf.bak
cp ./hostapd.conf /etc/hostapd/
chown root:root /etc/hostapd/hostapd.conf

#setup dhcp server

cp /etc/default/isc-dhcp-server /etc/default/isc-dhcp-server.bak
cp ./isc-dhcp-server /etc/default/isc-dhcp-server

cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak
cp ./dhcpd.conf /etc/dhcp/dhcpd.conf
chown root:root /etc/dhcp/dhcpd.conf

#kill any autostart

update-rc.d -f hostapd remove
update-rc.d -f isc-dhcp-server remove

#autostart everything (this will be taken care of in the normal script)

ifdown wlan0
ifup wlan0
/etc/init.d/isc-dhcp-server start
hostapd -B /etc/hostapd/hostapd.conf
