#!/bin/bash

function absPath {
  echo $(cd $(dirname $1); pwd)/$(basename $1)
}

hadoop_conf_dir=`absPath "hadoop_conf/conf"`


echo "stop any running namenode"
hadoop-*/sbin/hadoop-daemon.sh --config $hadoop_conf_dir --script hdfs stop namenode

echo "stop any running datanode"
hadoop-*/sbin/hadoop-daemon.sh --config $hadoop_conf_dir --script hdfs stop datanode

echo "stop any running resourcemanager"
hadoop-*/sbin/yarn-daemon.sh --config $hadoop_conf_dir stop resourcemanager

echo "stop any running nodemanager"
hadoop-*/sbin/yarn-daemon.sh --config $hadoop_conf_dir stop nodemanager

cd solr*

cd example
java -DSTOP.PORT=7983 -DSTOP.KEY=key -jar start.jar --stop

cd ../example2
java -DSTOP.PORT=6574 -DSTOP.KEY=key -jar start.jar --stop
