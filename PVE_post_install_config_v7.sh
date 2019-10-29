#!/bin/bash

echo ""
echo "     +----------------------+"
echo "     | vCDN cPoP Orange MEA |"
echo "     |   PVE post-install   |"
echo "     |      Release 7       |"
echo "     +----------------------+"
echo ""

##
## Initial updates
##

logfile="/root/pve_post_install.log"
echo "Log file: $logfile"

echo -e "Update .bashrc..."
echo "`date` - Update .bashrc..." >> $logfile
cat << EOF >> ~/.bashrc
export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
EOF
source ~/.bashrc
echo -e "[  \033[1m\033[32mOK\033[0m  ] .bashrc updated"
echo "`date` - Done" >> $logfile

# Check PVE release number
echo -e "Check PVE version...                                        \c"
echo "`date` - Check PVE version..." >> $logfile
pverel=`pveversion | awk -v FS=/ '{print $2}' | awk -v FS=- '{print $1}' | awk -v FS=. '{print $1}'`
pverelmin=`pveversion | awk -v FS=/ '{print $2}' | awk -v FS=- '{print $1}'`
echo -e "[\033[1m\033[32m$pverel\033[0m]"
echo "`date` - Done: PVE version=$pverel" >> $logfile

# PVE repo configuration
#   - the no-subscription repo has an issue with glusterfs:
#     + it has glusterfs-common and glusterfs-client in 6.5.1 (the expected release)
#     + but the glusterfs-server is still 5.5.3 (causing troubles)
#   - we use our OINIS repo consequently:
#     + 90.84.143.215 is the IP address of the CDN repopve1 
#     + 90.84.143.215/debiandeb10 contains the debian regular repo
#     + 90.84.143.215/debiansec10 contains the debian security updates
#     + 90.84.143.215/pvedeb6.0 contains the pve6.0 enterprise repo
#
cat << EOF > /etc/apt/sources.list
## NEW CONFIGURATION FOR USING THE OINIS REPO:
# regular updates
deb [trusted=yes] http://90.84.143.215/debiandeb10/ ./
# security updates
deb [trusted=yes] http://90.84.143.215/debiansec10/ ./
# pve enterprise
deb [trusted=yes] http://90.84.143.215/pvedeb6.0/ ./
EOF

cat << EOF > /etc/apt/sources.list.d/pve-enterprise.list
## OLD CONFIGURATION:
#deb https://enterprise.proxmox.com/debian buster pve-enterprise
EOF

echo -e "[  \033[1m\033[32mOK\033[0m  ]  repos update"
echo "`date` - Done" >> $logfile

# # Configure HTTP proxy to be the one deployed in the dedicated container on Passys
# echo "Configure HTTP proxy (Passys)..."
# echo "`date` - Configure HTTP proxy (Passys)..." >> $logfile
# cat << EOF > /etc/environment
# export http_proxy=http://90.84.143.118:8080
# export https_proxy=http://90.84.143.118:8080
# EOF
# source /etc/environment
# echo -e "[  \033[1m\033[32mOK\033[0m  ] HTTP proxy"
# echo "`date` - Done" >> $logfile

# Update and upgrade the system
echo "Update the system..."
echo "`date` - Update the system..." >> $logfile
cat << EOF > /etc/export
export DEBIAN_FRONTEND=noninteractive
export DEBIAN_PRIORITY=critical
EOF
source /etc/export
apt-get -q -y -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" update >> $logfile
sleep 2
echo -e "[  \033[1m\033[32mOK\033[0m  ] apt-get update"
echo "`date` - Done" >> $logfile

echo "Upgrade the system (THIS MAY TAKE A WHILE)..."
echo "`date` - Upgrade the system..." >> $logfile
apt-get -q -y -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" dist-upgrade >> $logfile
sleep 2
echo -e "[  \033[1m\033[32mOK\033[0m  ] apt-get upgrade"
echo "`date` - Done" >> $logfile

# Install additional packages
echo "Install additional packages (THIS MAY TAKE A WHILE)..."
echo "`date` - Install additional packages..." >> $logfile
apt-get -q -y -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" install glusterfs-server lshw tmux htop atop iftop nload curl ethtool iproute2 >> $logfile
sleep 2
echo -e "[  \033[1m\033[32mOK\033[0m  ] additional packages"
echo "`date` - Done" >> $logfile

# Install ntpdate package
echo -e "Installing ntpdate. \033\033[31mIf questionned at next prompt, enter Y\033[0m"
echo "`date` - Install ntpdate package..." >> $logfile
apt-get -q -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" install ntpdate >> $logfile
sleep 2
echo -e "[  \033[1m\033[32mOK\033[0m  ] ntpdate"
echo "`date` - Done" >> $logfile

##
## PVE customisation: subscription, time, mailing list, NDS, NTP
##

echo "Starting PVE tweaking..."

# Disable the subscription message
echo "Disable the subscription message..."
echo "`date` - Disable the subscription message..." >> $logfile
sed -i "s/data.status !== 'Active'/false/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
echo -e "[  \033[1m\033[32mOK\033[0m  ] remove message"
echo "`date` - Done" >> $logfile

# Update timezone - to be customized... ?!?
echo "Update timezone..."
echo "`date` - Update timezone..." >> $logfile
dpkg-reconfigure tzdata
echo -e "[  \033[1m\033[32mOK\033[0m  ] time zone to UTC"
echo "`date` - Done" >> $logfile

# Update DNS
echo "Update DNS..."
echo "`date` - Update DNS..." >> $logfile
echo "nameserver 193.251.253.128" >> /etc/resolv.conf
echo "nameserver 193.251.253.129" >> /etc/resolv.conf
echo -e "[  \033[1m\033[32mOK\033[0m  ] DNS"
echo "`date` - Done" >> $logfile

# NTP
echo "Update NTP..."
echo "`date` - Update NTP..." >> $logfile
sed 's/^NTPSERVERS=\(.*\)/NTPSERVERS=\"ntp1.opentransit.net ntp2.opentransit.net\" #\1/' /etc/default/ntpdate > /root/tmp_ntpdate
cp /root/tmp_ntpdate /etc/default/ntpdate
echo -e "[  \033[1m\033[32mOK\033[0m  ] NTP"
echo "`date` - Done" >> $logfile

##
## data disk configuration
##

echo "Gather information on data disk (RAID5 volume)..."
echo "`date` - Gather information on data disk (RAID5 volume)..." >> $logfile
echo "Output of 'fdisk -l':"
fdisk -l

datadisk="sdb"
newdatadisk=$datadisk
while [ "$Rep0" != 'y' ];
do
  read -p "Data disk is sdb, is that right? (y/n) " Rep0
  if [ "$Rep0" = 'n' ]
  then
    read -p "Please specify the data disk: " newdatadisk
    echo -e "\033[31mYou said data disk is $newdatadisk, are you sure? (y/n) \033[0m \c"
    read Rep0
  fi
done
datadisk=$newdatadisk
echo -e "[  \033[1m\033[32mOK\033[0m  ] gather disk"
echo "`date` - Done" >> $logfile

echo "Start data disk configuration..."
echo "`date` - Start data disk configuration..." >> $logfile
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk /dev/$datadisk
  g # create a new empty GPT partition table
  n # add a new partition
  1 # partition number 1
    # first sector - use default: start at beginning of disk (sector 2048)
    # last sector - use default: extend partition to end of disk
  w # write the partition table
  q # and we're done
EOF
datapart="$datadisk""1"
mke2fs -t ext4 /dev/$datapart
mountpoint="/mnt/data/"
mkdir $mountpoint
echo "/dev/$datapart $mountpoint ext4 defaults 0 2" >> /etc/fstab
echo -e "[  \033[1m\033[32mOK\033[0m  ] disk config"
echo "`date` - Done" >> $logfile

# Add local-data disk to PVE storage manager
echo "Add local-data disk to PVE storage manager..."
echo "`date` - Add local-data disk to PVE storage manager..." >> $logfile
pvesm add dir local-data --path /mnt/data --content images,rootdir
echo -e "[  \033[1m\033[32mOK\033[0m  ] local-data disk"
echo "`date` - Done" >> $logfile

##
## Network configuration
##

# Gather network interfaces information
echo "Gather network interfaces information..."
echo "`date` - Gather network interfaces information..." >> $logfile
ip link show
# build a check with: ip link show | sed 's/.*loopback.*//I' | sed 's/^[0-9]: \(.*\):.*/\1 /' | sed 's/link\/ether \(.*\) brd.*/\1/'
while [ "$Rep1" != 'y' ];
do
  read -p "Enter the physical interface name used for client-serving: " intClient
  echo -e "\033[31mInterface $intClient will be used for client-serving traffic, are you sure? (y/n) \033[0m \c"
  read Rep1
done

while [ "$Rep2" != 'y' ];
do
  read -p "Enter the physical interface name used for intra-site (back-toback): " intIntra
  echo -e "\033[31mInterface $intIntra will be used for intra-site traffic, are you sure? (y/n) \033[0m \c"
  read Rep2        
done
echo -e "[  \033[1m\033[32mOK\033[0m  ] gather network info"
echo "`date` - Done" >> $logfile

# remove 'iface ens2f0 inet manual' kind of lines in the interfaces network configuration file (client and intrasite)
sed -i "/iface $intClient inet manual/d" /etc/network/interfaces
sed -i "/iface $intIntra inet manual/d" /etc/network/interfaces
    
# configure linux bridge in the interfaces network configuration file
echo "Configure linux bridge..."
echo "`date` - Configure bridge-utils..." >> $logfile
cat << END >>/etc/network/interfaces
iface $intClient inet manual
auto vmbr1
iface vmbr1 inet manual
  bridge_ports $intClient
  bridge_stp off
  bridge_fd 0
  bridge_maxwait 0
        
iface $intIntra inet manual
auto vmbr2
iface vmbr2 inet manual
  bridge_ports $intIntra
  bridge_stp off
  bridge_fd 0
  bridge_maxwait 0
END
echo -e "[  \033[1m\033[32mOK\033[0m  ] linux bridge"
echo "`date` - Done" >> $logfile

read -p "----------------------------------------> Press a key"

##
## PVE cluster configuration
##

echo "Gather cluster information..."
echo "`date` - Gather cluster information..." >> $logfile
mngtIP=`ip -4 -o addr show | awk '{print \$4}'| sed -n '2p'| cut -d / -f 1`
newmngtIP=$mngtIP
while [ "$Rep3" != 'y' ];
do
  read -p "Management IP address discovered is $mngtIP, is that right? (y/n) " Rep3
  if [ "$Rep3" = 'n' ]
  then
    echo -e "\033[31mDisplaying available IPv4 IP addresses:\033[0m \c"
    ip -4 a
    read -p "Please enter the management IP of the server: " newmngtIP
    echo -e "\033[31mYou said management IP of the server is $newmngtIP, are you sure? (y/n) \033[0m \c"
    read Rep3
  fi
done
mngtIP=$newmngtIP
echo -e "[  \033[1m\033[32mOK\033[0m  ] gather cluster info"
echo "`date` - Done" >> $logfile

echo "Select node in the PVE cluster..."
echo "`date` - Select node in the PVE cluster..." >> $logfile
while [ "$Rep" != 'y' ];
do
  read -p "Is it the first node of the cluster? (y/n) " Rep4
  if [ "$Rep4" = 'y' ]
  then
    echo -e "\033[31mYou said this is the first node of the cluster, are you sure? (y/n) \033[0m \c"
    read Rep
  elif [ "$Rep4" = 'n' ]
  then
    echo -e "\033[31mYou said this is NOT the first node of the cluster, are you sure? (y/n) \033[0m \c"
    read Rep
  fi
done
echo -e "[  \033[1m\033[32mOK\033[0m  ] select node cluster"
echo "`date` - Done" >> $logfile

# Start glusterfs/cluster configuration
if [ "$Rep4" = 'y' ]
then
  ## this is the configuration for the first node of the cluster
  ## it particularly includes the creation of the shared storage (glusterfs) as well as the creation of the pve cluster

  # start and enable glusterfd daemon
  echo -e "Start and enable glusterd daemon....\c"
  echo "`date` - Start and enable glusterd daemon...." >> $logfile
  systemctl start glusterd
  sleep 5
    
  read -p "----------------------------------------> Press a key"
  
  systemctl enable glusterd
  sleep 5

  # create the glusterfs volume
  echo -e "Create the glusterfs storage....\c"
  echo "`date` - Create the glusterfs storage...." >> $logfile
  mkdir /mnt/glusterfsstorage
  gluster volume create glusterstorage $mngtIP:/mnt/glusterfsstorage force
  sleep 5
  echo -e "[  \033[1m\033[32mOK\033[0m  ] create volume"
  echo "`date` - Done" >> $logfile

  read -p "----------------------------------------> Press a key"

  # create the proxmox cluster
  echo -e "Create the cluster-cpop cluster...\c"
  echo "`date` - Create the cluster-cpop cluster..." >> $logfile
  pvecm create cluster-cpop
  sleep 5
  echo -e "[  \033[1m\033[32mOK\033[0m  ] create cluster"
  echo "`date` - Done" >> $logfile

  # start the gluster volume
  echo -e "Start the gluster volume...\c"
  echo "`date` - Start the gluster volume..." >> $logfile
  gluster volume start glusterstorage
  sleep 5
  echo -e "[  \033[1m\033[32mOK\033[0m  ] start volume"
  echo "`date` - Done" >> $logfile

  read -p "----------------------------------------> Press a key"

  # add the gluster volume to the proxmox cluster
  echo -e "Add the shared glusterfs storage to PVE...\c"
  echo "`date` - Add the shared glusterfs storage to PVE ..." >> $logfile
  pvesm add glusterfs Shared --server $mngtIP --path /mnt/pve/Shared --volume glusterstorage --content vztmpl,images,iso,backup
  sleep 5
  echo -e "[  \033[1m\033[32mOK\033[0m  ] add shared storage"
  echo "`date` - Done" >> $logfile

  read -p "----------------------------------------> Press a key"

elif [ "$Rep4" = 'n' ]
then
  ## this is the configuration for other nodes than the first node of the cluster
  ## it adds the node to the existing cluster and also adds the corresponding brick to the glusterfs shared storage

  while [ "$Rep5" != 'y' ];
  do
    read -p "Enter the IP of the first node : " ClusterIP
    echo -e "\033[31mYou said the First node of the cluster is $ClusterIP , are you sure?(y/n) \033[0m \c"
    read Rep5
  done

  # start and enable glusterfd daemon
  echo -e "Start and enable glusterd daemon....\c"
  echo "`date` - Start and enable glusterd daemon...." >> $logfile
  systemctl start glusterd
  sleep 5
  systemctl enable glusterd
  sleep 5

  read -p "----------------------------------------> Press a key"

  # add the second node to the PVE cluster
  echo -e "Add the second node to the PVE cluster...                \c"
  echo "`date` - Add the second node to the PVE cluster..." >> $logfile
  pvecm add $ClusterIP
  sleep 5
  echo -e "[  \033[1m\033[32mOK\033[0m  ] add"
  echo "`date` - Done" >> $logfile

  read -p "----------------------------------------> Press a key"

  # add the node to the glusterfs
  echo -e "Add the node to the shared glusterfs volume...          \c"
  echo "`date` - Add the node to the shared glusterfs volume..." >> $logfile
  mkdir /mnt/glusterfsstorage
  ssh $ClusterIP gluster peer probe $mngtIP
  sleep 5
  echo -e "[  \033[1m\033[32mOK\033[0m  ] add"
  echo "`date` - Done" >> $logfile

  read -p "----------------------------------------> Press a key"

  # add the brick to the glusterfs
  echo -e "Add the brick to the shared glusterfs volume...          \c"
  echo "`date` - Add the brick to the shared glusterfs volume..." >> $logfile
  ssh $ClusterIP gluster volume add-brick glusterstorage $mngtIP:/mnt/glusterfsstorage force
  sleep 5
  echo -e "[  \033[1m\033[32mOK\033[0m  ] add"
  echo "`date` - Done" >> $logfile

  read -p "----------------------------------------> Press a key"

fi

echo "Restart network..."
echo "`date` - Restart network..." >> $logfile
systemctl restart networking.service
echo -e "[  \033[1m\033[32mOK\033[0m  ] restart"
echo "`date` - Done" >> $logfile

echo ""
echo "------------------------------"
echo "Post configuration is finished"
echo "------------------------------"
echo ""
echo "A reboot is requiered to apply the new system configuration"
read -p "Do you want to reboot now? (y/n) " doareb
if [ "$doareb" = 'y' ]
then
  reboot
fi

exit 0
