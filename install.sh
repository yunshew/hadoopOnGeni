#!/bin/bash

# Scripted Hortonworks Data Platform 2.6.2 based on manual installation
# Author: Fei Ding and Yupeng Wu, based on https://github.com/hortonworks/HDP-Public-Utilities
# This is for CentOs 7

# Get the hostname of NameNode
HDFS_HOSTNAME="$(hostname)"
shortname="$(echo $(hostname) | cut -d. -f1)"
replace="namenode"
HDFS_NAMENODE=${HDFS_HOSTNAME//$shortname/$replace}
HDFS_SECONDARY="$HDFS_NAMENODE"
YARN_RESOURCEMANAGER="$HDFS_NAMENODE"
ZOOKEEPER_QUORUM="$HDFS_NAMENODE"

# Get the hostname of DataNode
if ! [ "$(echo $(hostname) | cut -d. -f1)" = "namenode" ]; then
  echo "get datanode hostname";
  HDFS_DATANODE="$HDFS_HOSTNAME"
  YARN_NODEMANAGER="$HDFS_DATANODE"
fi


# Software requirements
sudo yum -y update
sudo yum install -y scp
sudo yum install -y curl
sudo yum install -y tar
sudo yum install -y unzip
sudo yum install -y wget
sudo yum install -y ntp

# These must match the location used by the RPMs
#HADOOP_LIB_DIR="/usr/lib/hadoop"
#YARN_LIB_DIR="/usr/lib/hadoop-yarn"
#MAPRED_LIB_DIR="/usr/lib/hadoop-mapreduce"

# Add from properies script
source /tmp/hadoopOnGeni/setup.properies
cd /tmp/

# Download java package
wget --no-cookies \
--no-check-certificate \
--header "Cookie: oraclelicense=accept-securebackup-cookie" \
$java_repo_location -O jdk-8-linux-x64.tar.gz

# Download RPM repo configuration
sudo wget -nv $hdp_repo_location -O /etc/yum.repos.d/hdp.repo

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


#prepare the environment
sudo su -c "systemctl enable ntpd; systemctl start ntpd"
sudo su -c "setenforce 0"
sudo su -c "systemctl stop firewalld; systemctl mask firewalld"

cd /tmp/hadoopOnGeni/
# Source helper files
source scripts/directories.sh
source scripts/users.sh

#create hadoop group and system users
echo "Creating Hadoop group . . ."
sudo groupadd $HADOOP_GROUP
echo "Creating Hadoop system accounts . . ."
sudo useradd -g $HADOOP_GROUP $HDFS_USER
sudo useradd -g $HADOOP_GROUP $MAPRED_USER
sudo useradd -g $HADOOP_GROUP $TEMPLETON_USER
sudo useradd -g $HADOOP_GROUP $ZOOKEEPER_USER
sudo useradd -g $HADOOP_GROUP $SPARK_USER
#sleep 3

#install hadoop core packages from yum
sudo yum install -y hadoop hadoop-hdfs hadoop-libhdfs hadoop-yarn hadoop-mapreduce hadoop-client openssl

#NameNode directories
if [ "$(echo $(hostname) | cut -d. -f1)" = "namenode" ]; then
  echo "creating namenode directories";
  sudo mkdir -p $DFS_NAME_DIR;
  sudo chown -R $HDFS_USER:$HADOOP_GROUP $DFS_NAME_DIR;
  sudo chmod -R 755 $DFS_NAME_DIR;
fi

#DataNode directories
if ! [ "$(echo $(hostname) | cut -d. -f1)" = "namenode" ]; then
  echo "creating datanode directories";
  sudo mkdir -p $DFS_DATA_DIR;
  sudo chown -R $HDFS_USER:$HADOOP_GROUP $DFS_DATA_DIR;
  sudo chmod -R 750 $DFS_DATA_DIR;
fi

#All HDFS hosts
echo "All HDFS hosts"
sudo mkdir -p $HDFS_LOG_DIR
sudo chown -R $HDFS_USER:$HADOOP_GROUP $HDFS_LOG_DIR
sudo chmod -R 755 $HDFS_LOG_DIR

sudo mkdir -p $HDFS_PID_DIR
sudo chown -R $HDFS_USER:$HADOOP_GROUP $HDFS_PID_DIR
sudo chmod -R 755 $HDFS_PID_DIR

# All YARN hosts
echo "All YARN hosts"
sudo mkdir -p $YARN_LOG_DIR;
sudo chown -R $YARN_USER:$HADOOP_GROUP $YARN_LOG_DIR;
sudo chmod -R 755 $YARN_LOG_DIR;

sudo mkdir -p $YARN_LOCAL_LOG_DIR;
sudo chown -R $YARN_USER:$HADOOP_GROUP $YARN_LOCAL_LOG_DIR;
sudo chmod -R 755 $YARN_LOCAL_LOG_DIR;

sudo mkdir -p $YARN_PID_DIR;
sudo chown -R $YARN_USER:$HADOOP_GROUP $YARN_PID_DIR;
sudo chmod -R 755 $YARN_PID_DIR;

sudo mkdir -p $YARN_LOCAL_DIR;
sudo chown -R $YARN_USER:$HADOOP_GROUP $YARN_LOCAL_DIR;
sudo chmod -R 755 $YARN_LOCAL_DIR;

#JobHistory server logs
sudo mkdir -p $MAPRED_LOG_DIR;
sudo chown -R $YARN_USER:$HADOOP_GROUP $MAPRED_LOG_DIR;
sudo chmod -R 755 $MAPRED_LOG_DIR;
#JobHistory Server Process ID
sudo mkdir -p $MAPRED_PID_DIR;
sudo chown -R $MAPRED_USER:$HADOOP_GROUP $MAPRED_PID_DIR;
sudo chmod -R 755 $MAPRED_PID_DIR;

echo "Editing Hadoop core configuration files . . ."
cd /tmp/hadoopOnGeni/configuration_files/core_hadoop
sudo sed -i "s/TODO-NAMENODE-HOSTNAME/$HDFS_NAMENODE/g" ./core-site.xml
sudo sed -i 's;TODO-FS-CHECKPOINT-DIR;'"$FS_CHECKPOINT_DIR"';g' ./core-site.xml
sudo sed -i 's;TODO-DFS-NAME-DIR;'"$DFS_NAME_DIR"';g' ./hdfs-site.xml
sudo sed -i 's;TODO-DFS-DATA-DIR;'"$DFS_DATA_DIR"';g' ./hdfs-site.xml
sudo sed -i "s/TODO-NAMENODE-HOSTNAME/$HDFS_NAMENODE/g" ./hdfs-site.xml
sudo sed -i "s/TODO-SECONDARYNAMENODE-HOSTNAME/$HDFS_SECONDARY/g" ./hdfs-site.xml

# YARN
sudo sed -i "s/TODO-RMNODE-HOSTNAME/$YARN_RESOURCEMANAGER/g" ./yarn-site.xml
sudo sed -i 's;TODO-YARN-LOCAL-DIR;'"$YARN_LOCAL_DIR"';g' ./yarn-site.xml
sudo sed -i 's;TODO-YARN-LOG-DIR;'"$YARN_LOG_DIR"';g' ./yarn-site.xml

# MR on YARN
sudo sed -i "s/TODO-JOBHISTORYNODE-HOSTNAME/$YARN_RESOURCEMANAGER/g" ./mapred-site.xml
sudo sed -i "s/TODO-JOBHISTORYNODE-HOSTNAME/$YARN_RESOURCEMANAGER/g" ./mapred-site.xml
#sudo sed -i 's/-XX:NewSize=[0-9*m|G]*/-XX:NewSize=64m/g' ./hadoop-env.sh
#sudo sed -i 's/-XX:MaxNewSize=[0-9*m|G]*/-XX:MaxNewSize=64m/g' ./hadoop-env.sh
#sudo sed -i 's/-Xmx[0-9*m|G]*/-Xmx512m/g' ./hadoop-env.sh
#sudo sed -i 's/-Xms[0-9*m|G]*/-Xms512m/g' ./hadoop-env.sh


# Workaround: NEED TO FIX THE BAD HEALTH CHECK: port 50060 instead of 8042
sudo sed -i "s/50060/8042/g" ./health_check

#sudo echo "$HDFS_DATANODE" | tr ',' '\n' > "$HADOOP_CONF_DIR/slaves"


#All hosts
echo "Deploying Hadoop core configuration files . . ."
sudo rm -rf $HADOOP_CONF_DIR
sudo mkdir -p $HADOOP_CONF_DIR
sudo cp /tmp/hadoopOnGeni/configuration_files/core_hadoop/* $HADOOP_CONF_DIR
sudo chmod a+x $HADOOP_CONF_DIR
sudo chown -R $HDFS_USER:$HADOOP_GROUP $HADOOP_CONF_DIR/../
sudo chmod -R 755 $HADOOP_CONF_DIR/../

#workarounds
#sudo ln -s $HADOOP_LIB_DIR/libexec $YARN_LIB_DIR
#sudo ln -s $HADOOP_LIB_DIR/libexec $MAPRED_LIB_DIR
#This should not be necessary
#sudo ln -s $MAPRED_LOG_DIR $MAPRED_LIB_DIR/logs

#Boot up HDFS
#NameNode
if [ "$(echo $(hostname) | cut -d. -f1)" = "namenode" ]; then
  echo "namenode boot up HDFS";
  #formatting HDFS
  sudo su $HDFS_USER -c "echo Y|/usr/hdp/current/hadoop-hdfs-namenode/../hadoop/bin/hdfs namenode -format";
  #starting HDFS
  sudo su $HDFS_USER -c "/usr/hdp/current/hadoop-hdfs-namenode/../hadoop/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR start namenode";

  #creating base folders in HDFS
  sudo su $HDFS_USER -c "hdfs dfs -mkdir -p /user/hdfs"
fi

#DataNode
if ! [ "$(echo $(hostname) | cut -d. -f1)" = "namenode" ]; then
  echo "datanode starting HDFS";
  #starting HDFS
  sudo su $HDFS_USER -c "/usr/hdp/current/hadoop-hdfs-datanode/../hadoop/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR start datanode";
fi

#Boot up YARN
# All hosts
sudo su $HDFS_USER -c "hdfs dfs -mkdir -p /hdp/apps/$hdp_version/mapreduce/"
sudo su $HDFS_USER -c "hdfs dfs -put /usr/hdp/current/hadoop-client/mapreduce.tar.gz /hdp/apps/$hdp_version/mapreduce/"
sudo su $HDFS_USER -c "hdfs dfs -chown -R hdfs:hadoop /hdp"
sudo su $HDFS_USER -c "hdfs dfs -chmod -R 555 /hdp/apps/$hdp_version/mapreduce"
sudo su $HDFS_USER -c "hdfs dfs -chmod 444 /hdp/apps/$hdp_version/mapreduce/mapreduce.tar.gz"


#YARN_RESOURCEMANAGER
if [ "$(echo $(hostname) | cut -d. -f1)" = "namenode" ]; then
  sudo su $YARN_USER -c "/usr/hdp/current/hadoop-yarn-resourcemanager/sbin/yarn-daemon.sh --config $HADOOP_CONF_DIR start resourcemanager"
  #JobHistory server to set up directories on HDFS
  sudo su $HDFS_USER -c "hdfs dfs -mkdir -p /mr-history/tmp";
  sudo su $HDFS_USER -c "hdfs dfs -chmod -R 1777 /mr-history/tmp";
  sudo su $HDFS_USER -c "hdfs dfs -mkdir -p /mr-history/done";
  sudo su $HDFS_USER -c "hdfs dfs -chmod -R 1777 /mr-history/done";
  sudo su $HDFS_USER -c "hdfs dfs -chown -R $MAPRED_USER:$HDFS_USER /mr-history";
  sudo su $HDFS_USER -c "hdfs dfs -mkdir -p /app-logs";
  sudo su $HDFS_USER -c "hdfs dfs -chmod -R 1777 /app-logs";
  sudo su $HDFS_USER -c "hdfs dfs -chown $YARN_USER:$HDFS_USER /app-logs";
  #JobHistory server
  sudo su $YARN_USER -c "/usr/hdp/current/hadoop-mapreduce-historyserver/sbin/mr-jobhistory-daemon.sh --config $HADOOP_CONF_DIR start historyserver";
fi

#YARN_NODEMANAGER
if ! [ "$(echo $(hostname) | cut -d. -f1)" = "namenode" ]; then
  sudo su $YARN_USER -c "/usr/hdp/current/hadoop-yarn-nodemanager/sbin/yarn-daemon.sh --config $HADOOP_CONF_DIR start nodemanager"
  #change permissions on the container-executor file
  sudo su $YARN_USER -c "chown -R root:hadoop /usr/hdp/current/hadoop-yarn*/bin/container-executor";
  sudo su $YARN_USER -c "chmod -R 6050 /usr/hdp/current/hadoop-yarn*/bin/container-executor";
fi


#startup scripts
sudo tee -a /etc/profile << 'EOF'

export HADOOP_CONF_DIR=/etc/hadoop/conf/
export PATH=$HADOOP_CONF_DIR:$PATH
export JAVA_HOME=/usr/java/default
export PATH=$JAVA_HOME/bin:$PATH
EOF

source /etc/profile
java -version


# Install ZooKeeper
sudo yum -y install zookeeper-server
echo "Creating ZooKeeper directories . . ."
sudo mkdir -p $ZOOKEEPER_LOG_DIR
sudo chown -R $ZOOKEEPER_USER:$HADOOP_GROUP $ZOOKEEPER_LOG_DIR
sudo chmod -R 755 $ZOOKEEPER_LOG_DIR
sudo mkdir -p $ZOOKEEPER_PID_DIR
sudo chown -R $ZOOKEEPER_USER:$HADOOP_GROUP $ZOOKEEPER_PID_DIR
sudo chmod -R 755 $ZOOKEEPER_PID_DIR
sudo mkdir -p $ZOOKEEPER_DATA_DIR
sudo chown -R $ZOOKEEPER_USER:$HADOOP_GROUP $ZOOKEEPER_DATA_DIR
sudo chmod -R 755 $ZOOKEEPER_DATA_DIR

# Initialize myid file
# only work for single node zk cluster
sudo sh -c "echo '1' >> $ZOOKEEPER_DATA_DIR/myid"

#ZooKeeper configuration
echo "Editing ZooKeeper configuration files . . ."
cd /tmp/hadoopOnGeni/configuration_files/zookeeper

sudo sed -i '/^dataDir/ c\dataDir='"$ZOOKEEPER_DATA_DIR"'' ./zoo.cfg

#ZOOKEEPER1=`echo ZOOKEEPER_QUORUM | tr ',' '\n' | sed -n '1 p'`
#ZOOKEEPER2=`echo ZOOKEEPER_QUORUM | tr ',' '\n' | sed -n '2 p'`
#ZOOKEEPER3=`echo ZOOKEEPER_QUORUM | tr ',' '\n' | sed -n '3 p'`

sudo sed -i "s/TODO-ZOOKEEPER-SERVER-1/$ZOOKEEPER_QUORUM/g" ./zoo.cfg

#if [ "$ZOOKEEPER2" == "" ]; then
#    sudo sed -i '/TODO-ZOOKEEPER-SERVER-2/d' ./zoo.cfg;
#else
#    sudo sed -i "s/TODO-ZOOKEEPER-SERVER-2/$ZOOKEEPER2/g" ./zoo.cfg;
#fi
#if [ "$ZOOKEEPER3" == "" ]; then
#    sudo sed -i '/TODO-ZOOKEEPER-SERVER-3/d' ./zoo.cfg;
#else
#    sudo sed -i "s/TODO-ZOOKEEPER-SERVER-3/$ZOOKEEPER3/g" ./zoo.cfg;
#fi

echo "Deploying ZooKeeper configuration files . . ."
sudo rm -rf $ZOOKEEPER_CONF_DIR
sudo mkdir -p $ZOOKEEPER_CONF_DIR
sudo cp /tmp/hadoopOnGeni/configuration_files/zookeeper/* $ZOOKEEPER_CONF_DIR
sudo chmod a+x $ZOOKEEPER_CONF_DIR/
sudo chown -R $ZOOKEEPER_USER:$HADOOP_GROUP $ZOOKEEPER_CONF_DIR/../
sudo chmod -R 755 $ZOOKEEPER_CONF_DIR/../

# Start ZooKeeper
sudo su $ZOOKEEPER_USER -c "export ZOOCFGDIR=$ZOOKEEPER_CONF_DIR ; export ZOOCFG=zoo.cfg;
      source $ZOOKEEPER_CONF_DIR/zookeeper-env.sh ; $ZOOKEEPER_HOME/bin/zkServer.sh start"

#sudo su  zookeeper -c "export ZOOCFGDIR=/usr/hdp/current/zookeeper-server/conf ; export ZOOCFG=zoo.cfg
#; source /usr/hdp/current/zookeeper-server/conf/zookeeper-env.sh ; /usr/hdp/current/zookeeper-server/bin/zkServer.sh start"


# Create directories for Spark2
# for submitting Spark2 jobs
sudo mkdir -p /usr/hdp/current/spark2-client
# for launching Spark2 master processes, such as the Spark2 History Server
sudo mkdir -p /usr/hdp/current/spark2-history
# for the Spark2 Thrift Server
sudo mkdir -p /usr/hdp/current/spark2-thriftserver

# Install Spark2
source /tmp/hadoopOnGeni/setup.properies
sudo yum install -y spark2_${hdp_install_version}-master spark_${hdp_install_version}-python
sudo chown spark2:hadoop /var/log/spark2

# Configuration files
cd /tmp/hadoopOnGeni/configuration_files/spark2/
sudo sed -i "s/TODO-HIVE-HOSTNAME/$YARN_RESOURCEMANAGER/g" ./hive-site.xml
sudo sed -i "s/TODO-HISTORY-HOSTNAME/$YARN_RESOURCEMANAGER/g" ./spark-defaults.conf

sudo mkdir -p /usr/hdp/current/spark2-client/conf
sudo cp /tmp/hadoopOnGeni/configuration_files/spark2/* /usr/hdp/current/spark2-client/conf
sudo chmod a+x /usr/hdp/current/spark2-client/conf
sudo chown -R $SPARK_USER:$HADOOP_GROUP /usr/hdp/current/spark2-client/conf/../
sudo chmod -R 755 /usr/hdp/current/spark2-client/conf/../

# Create a spark User directory under /user/spark:
sudo su $HDFS_USER -c "hdfs dfs -mkdir -p /user/spark";
sudo su $HDFS_USER -c "hdfs dfs -chown spark:spark /user/spark";
sudo su $HDFS_USER -c "hdfs dfs -chmod -R 755 /user/spark";

# Create an HDFS Directory
sudo su $HDFS_USER -c "hdfs dfs -mkdir /spark2-history";
sudo su $HDFS_USER -c "hdfs dfs -chown -R spark:hadoop /spark2-history";
sudo su $HDFS_USER -c "hdfs dfs -chmod -R 777 /spark2-history";


# Master Node
if [ "$(echo $(hostname) | cut -d. -f1)" = "namenode" ]; then
  # start HDFS if you need to
  sudo sh $HADOOP_HOME/sbin/start-dfs.sh
  # start Spark
  sudo sh /usr/hdp/current/spark2-client/sbin/start-all.sh
fi

sudo sh /tmp/hadoopOnGeni/install_packages.sh

# Mount the dataset
sudo mkdir /mydata
sudo mount /dev/sda1 /mydata

# Create user directory
sudo su - hdfs -c 'hdfs dfs -mkdir /user/yunshew'
sudo su - hdfs -c 'hdfs dfs -chown -R yunshew /user/yunshew'

sudo mkdir /data/basemods_spark_data
sudo chmod 777 /data/basemods_spark_data/

