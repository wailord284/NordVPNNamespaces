#!/bin/bash
#https://nordvpn.com/tutorials/linux/openvpn/
#Ask the user what to do
user="UNIX USERNAME HERE" #User
vpn="us9419"
interface="e" #Set this to e or w. e = ethernet (ensp). w = wireless (wlan).
protocol="udp" #Set this to tcp or udp for the vpn connection
namespace="vpn" #The name to use for the namespace
vpnsource="vpnsource0" #Source for the vpn
vpndest="vpndest0" #Destination for the VPN
echo "What would you like to do?"
echo "1)	Create the VPN namespace"
echo "2)	Disable the VPN namespace"
echo "3)	Download/Update nordvpn profiles"
echo "4)	Exit"
read -e -r selection
selection=${selection:-1}

case "$selection" in

	1)
	# Running specific applications through a VPN with network namespaces
	# Initial state
	echo "Enabling the VPN namespace..."
	prevpn=$(curl -s ifconfig.co)

	# Create network namespace - vpn
	sudo ip netns add "$namespace"

	# Add loopback adapter to vpn and start networking
	sudo ip netns exec "$namespace" ip addr add 127.0.0.1/8 dev lo
	sudo ip netns exec "$namespace" ip link set lo up

	# Create a veth pair - vpndest0 and vpnsource0
	# (This will be our tunnel from vpnsource0 (inside vpn) to vpndest0)
	sudo ip link add "$vpndest" type veth peer name "$vpnsource"
	sudo ip link set "$vpndest" up
	sudo ip link set "$vpnsource" netns "$namespace" up

	# Assign local IP address to vpnsource0 and vpndest0
	# Route all traffic inside vpnsource0 to vpndest0
	sudo ip addr add 10.200.200.1/24 dev vpndest0
	sudo ip netns exec "$namespace" ip addr add 10.200.200.2/24 dev "$vpnsource"
	sudo ip netns exec "$namespace" ip route add default via 10.200.200.1 dev "$vpnsource"

	# Configure iptables
	# Route all traffic from vpndest0 to ethernet - e+ to match enp... - $interface should be e or w
	# Change to -o w+ if using WiFi
	iptables -t nat -A POSTROUTING -s 10.200.200.0/24 -o "$interface"+ -j MASQUERADE

	# Allow ipv4 forwarding
	sysctl -q net.ipv4.ip_forward=1

	#Set a new DNS - 1.1.1.1 is cloudflare
	sudo mkdir -p /etc/netns/"$namespace"
	sudo sh -c "echo 'nameserver 1.1.1.1' > /etc/netns/$namespace/resolv.conf"
	#sudo sh -c "echo 'nameserver 1.1.1.1' > /etc/resolv.conf"

	# Start openvpn inside vpn network namespace. Run it in daemon mode so after our password it goes away
	sudo -v # sudo -v makes sure openvpn has a good timestamp
	sudo ip netns exec "$namespace" openvpn --config /etc/openvpn/ovpn_"$protocol"/"$vpn".nordvpn.com."$protocol".ovpn --daemon
	sleep 5s

	# We specify the user so we keep our profile, etc.
	postvpn=$(sudo ip netns exec "$namespace" sudo -u "$user" curl -s ifconfig.co)
	#Output the before and after IP address
	echo -e "\nBefore the VPN: $prevpn\nAfter the VPN: $postvpn"
	echo -e "To use the VPN, run commands like this:\nsudo ip netns exec $namespace sudo -u $user transmission-gtk > /dev/null 2>&1 &"
	;;

	2)
	# Undo previous steps and shutdown
	echo "Disabling the VPN namespace..."
	sudo sysctl -q net.ipv4.ip_forward=0
	sudo iptables -t nat -D POSTROUTING -s 10.200.200.0/24 -o "$interface"+ -j MASQUERADE

	sudo killall openvpn
	sudo ip link delete "$vpndest"
	sudo ip netns delete "$namespace"
	;;

	3)
	#setup nordvpn profiles
	sudo rm -r /etc/openvpn/ovpn_udp /etc/openvpn/ovpn_tcp
	cd /etc/openvpn/
	sudo wget https://downloads.nordcdn.com/configs/archives/servers/ovpn.zip
	sudo unzip /etc/openvpn/ovpn.zip
	sudo rm /etc/openvpn/ovpn.zip
	echo "New profiles installed to /etc/openvpn/opvn_tcp|udp"
	;;

	4)
	exit 0 ;;
esac
