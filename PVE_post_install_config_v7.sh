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

aptlogfile="/root/pve_post_install.log"
echo "Log file: $aptlogfile"

# Check PVE release number
echo -e "Check PVE version...                                        \c"
echo "`date` - Check PVE version..." >> $aptlogfile
pverel=`pveversion | awk -v FS=/ '{print $2}' | awk -v FS=- '{print $1}' | awk -v FS=. '{print $1}'`
pverelmin=`pveversion | awk -v FS=/ '{print $2}' | awk -v FS=- '{print $1}'`
echo -e "[\033[1m\033[32m$pverel\033[0m]"
echo "`date` - Done: PVE version=$pverel" > $aptlogfile

# PVE repo configuration
cat << EOF > /etc/apt/sources.list
deb http://ftp.debian.org/debian buster main contrib
deb http://ftp.debian.org/debian buster-updates main contrib

# PVE pve-no-subscription repository provided by proxmox.com,
# NOT recommended for production use
deb http://download.proxmox.com/debian/pve buster pve-no-subscription

# security updates
deb http://security.debian.org buster/updates main contrib
EOF

cat << EOF > /etc/apt/sources.list.d/pve-enterprise.list
## OLD CONFIGURATION:
#deb https://enterprise.proxmox.com/debian buster pve-enterprise
EOF

echo -e "  repos update                                              [\033[1m\033[32mdone\033[0m]"
echo "`date` - Done" >> $aptlogfile

# Configure HTTP proxy to be the one deployed in the dedicated container on Passys
echo "Configure HTTP proxy (Passys)..."
echo "`date` - Configure HTTP proxy (Passys)..." >> $aptlogfile
cat << EOF > /etc/environment
export http_proxy=http://90.84.143.118:8080
export https_proxy=http://90.84.143.118:8080
EOF
source /etc/environment
echo -e "  HTTP proxy                                                [\033[1m\033[32mdone\033[0m]"
echo "`date` - Done" >> $aptlogfile

# Update and upgrade the system
echo "Update the system..."
echo "`date` - Update the system..." >> $aptlogfile
cat << EOF > /etc/export
export DEBIAN_FRONTEND=noninteractive
export DEBIAN_PRIORITY=critical
EOF
source /etc/export
apt-get -q -y -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" update >> $aptlogfile
sleep 2
echo -e "  apt-get update                                            [\033[1m\033[32mdone\033[0m]"
echo "`date` - Done" >> $aptlogfile

echo "Upgrade the system (THIS MAY TAKE A WHILE)..."
echo "`date` - Upgrade the system..." >> $aptlogfile
apt-get -q -y -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" upgrade >> $aptlogfile
sleep 2
echo -e "  apt-get upgrade...                                        [\033[1m\033[32mdone\033[0m]"
echo "`date` - Done" >> $aptlogfile

# Install additional packages
echo "Install additional packages (THIS MAY TAKE A WHILE)..."
echo "`date` - Install additional packages..." >> $aptlogfile
apt-get -q -y -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" install glusterfs-server lshw tmux htop atop iftop nload curl ethtool iproute2 >> $aptlogfile
sleep 2
echo -e "  additional packages                                       [\033[1m\033[32mdone\033[0m]"
echo "`date` - Done" >> $aptlogfile

# Install ntpdate package
echo -e "Installing ntpdate. \033\033[31mIf questionned at next prompt, enter Y\033[0m"
echo "`date` - Install ntpdate package..." >> $aptlogfile
apt-get -q -y -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" install ntpdate >> $aptlogfile
sleep 2
echo -e "  ntpdate                                                   [\033[1m\033[32mdone\033[0m]"
echo "`date` - Done" >> $aptlogfile

##
## PVE customisation: subscription, time, mailing list, NDS, NTP
##

echo "Starting PVE tweaking..."

# Disable the subscription message
echo "Disable the subscription message..."
echo "`date` - Disable the subscription message..." >> $aptlogfile
if [ "$pverel" = '4' ]
then
  sed -i "s/if (data.status === 'Active')/if (true)/" /usr/share/pve-manager/ext6/pvemanagerlib.js
elif [ "$pverel" = '5' ] || [ "$pverel" = '6' ]; then
  sed -i "s/if (data.status === 'Active')/if (true)/" /usr/share/pve-manager/js/pvemanagerlib.js
fi
echo -e "  remove message                                            [\033[1m\033[32mdone\033[0m]"
echo "`date` - Done" >> $aptlogfile

# Update timezone - to be customized... ?!?
echo "Update timezone..."
echo "`date` - Update timezone..." >> $aptlogfile
dpkg-reconfigure tzdata
echo -e " time zone to UTC                                           [\033[1m\033[32mdone\033[0m]"
echo "`date` - Done" >> $aptlogfile

# Update DNS
echo "Update DNS..."
echo "`date` - Update DNS..." >> $aptlogfile
echo "nameserver 193.251.253.128" >> /etc/resolv.conf
echo "nameserver 193.251.253.129" >> /etc/resolv.conf
echo -e " DNS                                                        [\033[1m\033[32mdone\033[0m]"
echo "`date` - Done" >> $aptlogfile

# NTP
echo "Update NTP..."
echo "`date` - Update NTP..." >> $aptlogfile
sed 's/^NTPSERVERS=\(.*\)/NTPSERVERS=\"ntp1.opentransit.net ntp2.opentransit.net\" #\1/' /etc/default/ntpdate > /root/tmp_ntpdate
cp /root/tmp_ntpdate /etc/default/ntpdate
echo -e " NTP                                                        [\033[1m\033[32mdone\033[0m]"
echo "`date` - Done" >> $aptlogfile

##
## data disk configuration
##

echo "Gather information on data disk (RAID5 volume)..."
echo "`date` - Gather information on data disk (RAID5 volume)..." >> $aptlogfile
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
echo -e "  gather disk                                               [\033[1m\033[32mdone\033[0m]"
echo "`date` - Done" >> $aptlogfile

echo "Start data disk configuration..."
echo "`date` - Start data disk configuration..." >> $aptlogfile
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
echo -e "  disk config                                               [\033[1m\033[32mdone\033[0m]"
echo "`date` - Done" >> $aptlogfile

# Add local-data disk to PVE storage manager
echo "Add local-data disk to PVE storage manager..."
echo "`date` - Add local-data disk to PVE storage manager..." >> $aptlogfilepvesm
add dir local-data --path /mnt/data --content images,rootdir
echo -e "  local-data disk                                           [\033[1m\033[32mdone\033[0m]"
echo "`date` - Done" >> $aptlogfile

##
## Network configuration
##

# Gather network interfaces information
echo "Gather network interfaces information..."
echo "`date` - Gather network interfaces information..." >> $aptlogfile
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
echo -e "  gather network info                                       [\033[1m\033[32mdone\033[0m]"
echo "`date` - Done" >> $aptlogfile

# remove 'iface ens2f0 inet manual' kind of lines in the interfaces network configuration file (client and intrasite)
sed -i "/iface $intClient inet manual/d" /etc/network/interfaces
sed -i "/iface $intIntra inet manual/d" /etc/network/interfaces

# configure openvswitch in the interfaces network configuration file
echo "Configure linux bridge..."
echo "`date` - Configure bridge-utils..." >> $aptlogfile
cat << END >>/etc/network/interfaces
auto lo
iface lo inet loopback

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
echo -e "  linux bridge                                              [\033[1m\033[32mdone\033[0m]"
echo "`date` - Done" >> $aptlogfile

##
## PVE cluster configuration
##

echo "Gather cluster information..."
echo "`date` - Gather cluster information..." >> $aptlogfile
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
echo -e "  gather                                                    [\033[1m\033[32mdone\033[0m]"
echo "`date` - Done" >> $aptlogfile

echo "Select node in the PVE cluster..."
echo "`date` - Select node in the PVE cluster..." >> $aptlogfile
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
echo -e "  select                                                    [\033[1m\033[32mdone\033[0m]"
echo "`date` - Done" >> $aptlogfile

# Start glusterfs/cluster configuration
if [ "$Rep4" = 'y' ]
then
  ## this is the configuration for the first node of the cluster
  ## it particularly includes the creation of the shared storage (glusterfs) as well as the creation of the pve cluster

  # start and enable glusterfd daemon
  echo -e "Start and enable glusterd daemon....\c"
  echo "`date` - Start and enable glusterd daemon...." >> $aptlogfile
  systemctl start glusterd
  sleep 2
  systemctl enable glusterd
  sleep 2
  # create the glusterfs volume
  echo -e "Create the glusterfs storage....\c"
  echo "`date` - Create the glusterfs storage...." >> $aptlogfile
  mkdir /mnt/glusterfsstorage
  gluster volume create glusterstorage $mngtIP:/mnt/glusterfsstorage force
  sleep 2
  echo -e "  create                                                    [\033[1m\033[32mdone\033[0m]"
  echo "`date` - Done" >> $aptlogfile

  # create the proxmox cluster
  echo -e "Create the cluster-cpop cluster...\c"
  echo "`date` - Create the cluster-cpop cluster..." >> $aptlogfile
  pvecm create cluster-cpop
  sleep 2
  echo -e "  create                                                    [\033[1m\033[32mdone\033[0m]"
  echo "`date` - Done" >> $aptlogfile

  # start the gluster volume
  echo -e "Start the gluster volume...\c"
  echo "`date` - Start the gluster volume..." >> $aptlogfile
  gluster volume start glusterstorage
  sleep 2
  echo -e "  start                                                     [\033[1m\033[32mdone\033[0m]"
  echo "`date` - Done" >> $aptlogfile

  # add the gluster volume to the proxmox cluster
  echo -e "Add the shared glusterfs storage to PVE...\c"
  echo "`date` - Add the shared glusterfs storage to PVE ..." >> $aptlogfile
  pvesm add glusterfs Shared --server $mngtIP --path /mnt/pve/Shared --volume glusterstorage --content vztmpl,images,iso,backup
  sleep 2
  echo -e "  add                                                       [\033[1m\033[32mdone\033[0m]"
  echo "`date` - Done" >> $aptlogfile

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
  echo "`date` - Start and enable glusterd daemon...." >> $aptlogfile
  systemctl start glusterd
  sleep 2
  systemctl enable glusterd
  sleep 2

  # add the second node to the PVE cluster
  echo -e "Add the second node to the PVE cluster...                \c"
  echo "`date` - Add the second node to the PVE cluster..." >> $aptlogfile
  pvecm add $ClusterIP
  sleep 2
  echo -e "  add                                                       [\033[1m\033[32mdone\033[0m]"
  echo "`date` - Done" >> $aptlogfile

  # add the node to the glusterfs
  echo -e "Add the node to the shared glusterfs volume...          \c"
  echo "`date` - Add the node to the shared glusterfs volume..." >> $aptlogfile
  mkdir /mnt/glusterfsstorage
  ssh $ClusterIP gluster peer probe $mngtIP
  sleep 2
  echo -e "  add                                                       [\033[1m\033[32mdone\033[0m]"
  echo "`date` - Done" >> $aptlogfile

  # add the brick to the glusterfs
  echo -e "Add the brick to the shared glusterfs volume...          \c"
  echo "`date` - Add the brick to the shared glusterfs volume..." >> $aptlogfile
  ssh $ClusterIP gluster volume add-brick glusterstorage $mngtIP:/mnt/glusterfsstorage force
  sleep 2
  echo -e "  add                                                       [\033[1m\033[32mdone\033[0m]"
  echo "`date` - Done" >> $aptlogfile
fi

echo "Restart network..."
echo "`date` - Restart network..." >> $aptlogfile
systemctl restart networking.service
echo -e "  restart                                                   [\033[1m\033[32mdone\033[0m]"
echo "`date` - Done" >> $aptlogfile

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
