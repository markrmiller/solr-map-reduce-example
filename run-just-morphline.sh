#!/bin/bash

# RUN JUST MORPHLINE SCRIPT - Handles all the environment setup, and just runs the morphline step.
#
#######################

# this gets hard coded in the configs - keep in sync
tmpdir=/tmp/solr-map-reduce

## Solr + Hadoop Dists
#######################

# Using Solr 4.8
solr_distrib="solr-4.10.1"
s
# you should replace with a local mirror. Find one at http://www.apache.org/dyn/closer.cgi/hadoop/common/hadoop-2.2.0/
hadoop_distrib="hadoop-2.2.0"

#########################################################
# NameNode port: 8020, DataNode ports: 50010, 50020, ResourceManager port: 8032 ZooKeeper port: 9983, Solr port: 8983
# NameNode web port: 50070, DataNodes web port: 50075
#########################################################


# collection to work with
collection=collection1

# return absolute path
function absPath {
  echo $(cd $(dirname $1); pwd)/$(basename $1)
}

hadoop_conf_dir=`absPath "hadoop_conf/conf"`
echo "hadoop_conf: $hadoop_conf_dir"

hadoopHome=`absPath "$hadoop_distrib"`
echo "HADOOP_HOME=$hadoopHome"
export HADOOP_HOME=$hadoopHome
export HADOOP_LOG_DIR=$tmpdir/logs
export HADOOP_CONF_DIR=$hadoop_conf_dir

# 
## Build an index with map-reduce and deploy it to SolrCloud
## Add --dry-run parameter to the end to see it run without 
## actually putting the documents into Solr!
#######################

source $solr_distrib/example/scripts/map-reduce/set-map-reduce-classpath.sh

$hadoop_distrib/bin/hadoop --config $hadoop_conf_dir jar $solr_distrib/dist/solr-map-reduce-*.jar -D 'mapred.child.java.opts=-Xmx500m' -libjars "$HADOOP_LIBJAR" --morphline-file readAvroContainer.conf --zk-host 127.0.0.1:9983 --output-dir hdfs://127.0.0.1:8020/outdir --collection $collection --log4j log4j.properties --go-live --verbose "hdfs://127.0.0.1:8020/indir"

