#!/bin/bash

# Scripted Hortonworks Data Platform 2.6.2 based on manual installation
# Author: Fei Ding and Yupeng Wu, based on https://github.com/hortonworks/HDP-Public-Utilities
# This is for CentOs 7
source /tmp/hadoopOnGeni/setup.properies
#prepare the environment
sudo su -c "systemctl enable ntpd; systemctl start ntpd"
sudo su -c "setenforce 0"
sudo su -c "systemctl stop firewalld; systemctl mask firewalld"

# Software requirements
# sudo yum -y update
sudo yum install -y scp
sudo yum install -y curl
sudo yum install -y tar
sudo yum install -y unzip
sudo yum install -y wget
sudo yum install -y ntp
sudo yum install -y openssl

# Download java package

wget --no-cookies \
--no-check-certificate \
--header "Cookie: oraclelicense=accept-securebackup-cookie" \
$java_repo_location -O /tmp/jdk-8-linux-x64.tar.gz

#set up java
sudo mkdir /usr/java && cd /usr/java
sudo tar -zxvf /tmp/jdk-8-linux-x64.tar.gz -C /usr/java
sudo rm /tmp/jdk-8-linux-x64.tar.gz
sudo mv /usr/java/jdk1.8.* /usr/java/jdk1.8
sudo ln -s /usr/java/jdk1.8 /usr/java/default
export JAVA_HOME=/usr/java/default
export PATH=$JAVA_HOME/bin:$PATH

# Put JAVA_HOME in the environment on node startup
sudo echo "export JAVA_HOME=/usr/java/default" > /etc/profile.d/java.sh
sudo echo "export PATH=$JAVA_HOME/bin:$PATH" > /etc/profile.d/java.sh


sudo sh /tmp/hadoopOnGeni/install_packages.sh

# Mount the dataset on namenode
if [ "$(echo $(hostname) | cut -d. -f1)" = "namenode" ]; then
    sudo mkdir /mydata
    sudo mount /dev/sdc1 /mydata
fi

sudo mkdir /data/basemods_spark_data
sudo chmod 777 /data/basemods_spark_data/

# Set some environment variables
sudo cat >> /etc/profile <<EOM
export EDITOR=vim
EOM

# Disable user prompting for connecting to unseen hosts.
sudo cat >> /etc/ssh/ssh_config <<EOM
    StrictHostKeyChecking no
EOM
# Setup password-less ssh between nodes
for user in $(ls /users/)
do
    ssh_dir=/users/$user/.ssh
    /usr/bin/geni-get key > $ssh_dir/id_rsa
    chmod 600 $ssh_dir/id_rsa
    chown $user: $ssh_dir/id_rsa
    ssh-keygen -y -f $ssh_dir/id_rsa > $ssh_dir/id_rsa.pub
    cat $ssh_dir/id_rsa.pub >> $ssh_dir/authorized_keys
    chmod 644 $ssh_dir/authorized_keys
done

if [ "$(echo $(hostname) | cut -d. -f1)" = "namenode" ]; then
  # Make the file system rwx by all.
  sudo chmod 777 /mydata

  # Make the NFS exported file system readable and writeable by all hosts in the
  # system (/etc/exports is the access control list for NFS exported file
  # systems, see exports(5) for more information).
  sudo echo "/mydata *(rw,sync,no_root_squash)"  /tmp/exports
  sudo cp /tmp/exports /etc/

  # Start the NFS service.
  sudo systemctl enable nfs-server.service
  sudo systemctl start nfs-server.service

  # Give it a second to start-up
  sleep 2
  touch /tmp/setup-nfs-done

if [ "$(echo $(hostname) | cut -d. -f1)" != "namenode" ]; then
  # Wait until nfs is properly set up
  # while [ "$(ssh namenode "[ -f /tmp/setup-nfs-done ] && echo 1 || echo 0")" != "1" ]; do
  #    sleep 1
  #done
    sleep 20
	# NFS clients setup: use the publicly-routable IP addresses for both the
  # server and the clients to avoid interference with the experiment.
    nfs_ip=`ssh namenode "hostname -i"`
    sudo mkdir /mydata
    sudo mount -t nfs4 $nfs_ip:/mydata /mydata
    sudo echo "$nfs_ip:/mydata /mydata nfs4 rw,sync,hard,intr,addr=`hostname -i` 0 0" >> /etc/fstab
fi
