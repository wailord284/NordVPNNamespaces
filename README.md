# A script to run NordVPN in a linux namespace

# How to use
- Edit the script and replace the "user" variable with your Linux username
- Change the "vpn" variable to a vpn server. Find a close one near you here: https://nordvpn.com/servers/tools/
- Change the "interface" variable to 'e' or 'w' for ethernet or wireless
- Change the "protocol" variable to udp or tcp
- Install OpenVPN

## Using the script
- Run the script with sudo and press option 3 to download the NordVPN profiles
- Run the script and press option 1 to create a namespace. You will be prompted to enter NordVPN credentials
- Once connected, run a new program in the namespace. For example, transmission
    * sudo ip netns exec vpn sudo -u username transmission-gtk
    * You may want to open a browser first and check your public IP to verify the VPN is working
