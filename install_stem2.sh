#!/bin/bash

# Scripted Hortonworks Data Platform 2.6.2 based on manual installation
# Author: Fei Ding and Yupeng Wu, based on https://github.com/hortonworks/HDP-Public-Utilities
# This is for CentOs 7

# Software requirements
sudo yum -y update
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
$java_repo_location -O jdk-8-linux-x64.tar.gz

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



#All hosts


# Mount the dataset
sudo mkdir /mydata
sudo mount /dev/sdc1 /mydata
# Create user directory
sudo su - hdfs -c 'hdfs dfs -mkdir /user/yunshew'
sudo su - hdfs -c 'hdfs dfs -chown -R yunshew /user/yunshew'
sudo mkdir /data/basemods_spark_data
sudo chmod 777 /data/basemods_spark_data/
