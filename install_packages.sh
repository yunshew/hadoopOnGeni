#!/bin/bash

curl "https://bootstrap.pypa.io/get-pip.py" -o "get-pip.py"
sudo python get-pip.py
sudo pip install --upgrade protobuf 
sudo pip install numpy h5py paramiko pbcore py4j pyspark

# All Worker Node
if ! [ "$(echo $(hostname) | cut -d. -f1)" = "namenode" ]; then
  # Download SMRT-analysis
  wget https://people.cs.clemson.edu/~luofeng/methylation/smrtanalysis.tar.gz -P /tmp/
  sudo tar -xhzvf /tmp/smrtanalysis.tar.gz -C /opt
fi


# Master Node
if [ "$(echo $(hostname) | cut -d. -f1)" = "namenode" ]; then
  wget https://people.cs.clemson.edu/~luofeng/methylation/smrtanalysis.tar.gz -P /tmp/
  sudo tar -xhzvf /tmp/smrtanalysis.tar.gz -C /opt
  wget https://people.cs.clemson.edu/~luofeng/methylation/basemods_spark_v3.tar.gz -P /tmp/
  sudo mkdir /opt/workspace_py
  sudo tar -xzf /tmp/basemods_spark_v3.tar.gz -C /opt/workspace_py
  sudo mv /opt/workspace_py/basemods_spark_v3 /opt/workspace_py/basemods_spark
  cd /opt/workspace_py/basemods_spark
  sudo chmod +x scripts/exec_sawriter.sh
  sudo chmod +x scripts/baxh5_operations.sh
  sudo chmod +x scripts/cmph5_operations.sh
  sudo chmod +x scripts/mods_operations.sh
  sudo sed -i "s/\/home\/hadoop/\/opt/g" parameters.conf
 
  # Copy your data to the master node of your Hadoop/Spark cluster.
  # sudo wget http://node.smrt.pdc-edu-lab-pg0.clemson.cloudlab.us/p6c4_ecoli_RSII_DDR2_with_15kb_cut_E01_1.tar.gz -P /data/
  # tar xvzf file.tar.gz
  # submit your job
  #$SPARK_HOME/bin/spark-submit basemods_spark_runner.py 
fi
