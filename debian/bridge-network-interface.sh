#!/bin/sh

# bridge-network-interface - configure a network bridge
#
# This service checks whether a physical network device that has been added
# is one of the ports in a bridge config, and if so, brings up the related
# bridge

set -e

if [ -z "$INTERFACE" ]; then
	echo "missing \$INTERFACE" >&2
	exit 1
fi

#default configuration
BRIDGE_HOTPLUG=no
[ -f /etc/default/bridge-utils ] && . /etc/default/bridge-utils

[ "$BRIDGE_HOTPLUG" = "no" ] && exit 0

. /lib/bridge-utils/bridge-utils.sh

if [ -d /run/network ]; then
   for i in $(ifquery --list --allow auto); do
	ports=$(ifquery $i | sed -n -e's/^bridge[_-]ports: //p')
	for port in $(bridge_parse_ports $ports); do
		case $port in
			$INTERFACE|$INTERFACE.*)
				create_vlan_port
				if [ -d /sys/class/net/$port ]; then
					ifup --allow auto $i
					if [ -f /proc/sys/net/ipv6/conf/$port/disable_ipv6 ]; then echo 1 > /proc/sys/net/ipv6/conf/$port/disable_ipv6;fi
					if [ "$(ifquery "$i"|sed -n -e's/^bridge[_-]hw: //p')" = "$port" ]; then
						ip link set dev "$i" address "$(ip link show dev "$port" 2>/dev/null|sed -n "s|.*link/ether \([^ ]*\) brd.*|\1|p")"
					fi
					brctl addif $i $port && ip link set dev $port up
				fi
				break
				;;
		esac
	done
   done
fi
