#!/bin/bash

# EXAMPLE SCRIPT - Start hdfs, yarn, and solr - then build the indexes with mapreduce and deploy them to Solr
#
# Requires: Solr trunk Java 1.7+, curl
# Should run on linux/OSX.
#######################

# Enable to see commands run for debugging
#set -x

# this gets hard coded in the configs - keep in sync
tmpdir=/tmp/solr-map-reduce

## Solr + Hadoop Dists
#######################

solr_ver="5.2.1"
solr_distrib="solr-$solr_ver"
solr_distrib_url="http://apache.mirrors.hoobly.com/lucene/solr/$solr_ver/$solr_distrib.tgz"

# you should replace with a local mirror. Find one at http://www.apache.org/dyn/closer.cgi/hadoop/common/hadoop-2.2.0/
hadoop_distrib="hadoop-2.6.0"
hadoop_distrib_url="http://www.trieuvan.com/apache/hadoop/common/$hadoop_distrib/$hadoop_distrib.tar.gz"

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

# clear any previous work
rm -f -r $tmpdir


## Get Hadoop
#######################

# get hadoop
if [ ! -f "$hadoop_distrib.tar.gz" ]; then
    curl -o $hadoop_distrib.tar.gz "$hadoop_distrib_url"
    if [[ $? -ne 0 ]]
    then
      echo "Failed to download hadoop at $hadoop_distrib"
      exit 1
    fi
else
    echo "hadoop distrib already exists"
fi

# extract hadoop
if [ ! -d "$hadoop_distrib" ]; then
    tar -zxf "$hadoop_distrib.tar.gz"
    if [[ $? -ne 0 ]]
    then
      echo "Failed to extract hadoop from $hadoop_distrib.tar.gz"
      exit 1
    fi
else
    echo "$hadoop_distrib.tar.gz already extracted"
fi

## Get Solr
#######################

# download solr
if [ ! -f "$solr_distrib.tgz" ]; then
    echo "Download solr dist $solr_distrib.tgz "
    curl -o $solr_distrib.tgz "$solr_distrib_url"
    if [[ $? -ne 0 ]]
    then
      echo "Failed to download Solr at $solr_distrib_url"
      exit 1
    fi
else
    echo "solr distrib already exists"
fi

# extract solr
if [ ! -d "$solr_distrib" ]; then
    tar -zxf "$solr_distrib.tgz"
    if [[ $? -ne 0 ]]
    then
      echo "Failed to extract Solr from $solr_distrib.tgz"
      exit 1
    fi
else
    echo "$solr_distrib.tgz already extracted"
fi

#  tar -zxf
cd $solr_distrib
unzip -o server/webapps/solr.war -d server/solr-webapp/webapp
# Patch map reduce environment for MacOS support. (sed expression shipped with solr only works on linux)
#patch server/scripts/map-reduce/set-map-reduce-classpath.sh < ../solr-map-reduce-classpath.sh.diff
cd ..

## Harmonize Conflicting Jar Dependencies
#######################

# Hadoop uses a lower version than Solr and the flags to use user libs first don't help this conflict
solr_http_client_version=4.4.1

find $hadoop_distrib -name "httpclient-*.jar" -type f -exec rm {} \;
find $hadoop_distrib -name "httpcore-*.jar" -type f -exec rm {} \;

solr_client=$solr_distrib/server/solr-webapp/webapp/WEB-INF/lib/httpclient-$solr_http_client_version.jar
solr_corer=$solr_distrib/server/solr-webapp/webapp/WEB-INF/lib/httpcore-$solr_http_client_version.jar

cp $solr_client $hadoop_distrib/share/hadoop/tools/lib
cp $solr_corer $hadoop_distrib/share/hadoop/tools/lib

cp $solr_client $hadoop_distrib/share/hadoop/kms/tomcat/webapps/kms/WEB-INF/lib
cp $solr_corer $hadoop_distrib/share/hadoop/kms/tomcat/webapps/kms/WEB-INF/lib

cp $solr_client $hadoop_distrib/share/hadoop/httpfs/tomcat/webapps/webhdfs/WEB-INF/lib
cp $solr_corer $hadoop_distrib/share/hadoop/httpfs/tomcat/webapps/webhdfs/WEB-INF/lib

cp $solr_client $hadoop_distrib/share/hadoop/common/lib
cp $solr_corer $hadoop_distrib/share/hadoop/common/lib


# Fix JAVA_HOME evaluation on OSX
#sed -e "s/\(export JAVA_HOME=\)(\(.*\))/\1\2/" -i -f $hadoop_distrib/libexec/hadoop-config.sh

## Start HDFS+YARN
#######################

# make the hadoop data dirs
mkdir -p $tmpdir/data/1/
mkdir -p $tmpdir/data/2/
mkdir -p $tmpdir/data/3/

# start hdfs
echo "start hdfs"

echo "stop any running namenode"
$hadoop_distrib/sbin/hadoop-daemon.sh --config $hadoop_conf_dir --script hdfs stop namenode

echo "format namenode"
$hadoop_distrib/bin/hdfs namenode -format -force

echo "start namenode"
$hadoop_distrib/sbin/hadoop-daemon.sh --config $hadoop_conf_dir --script hdfs start namenode

echo "stop any running datanode"
$hadoop_distrib/sbin/hadoop-daemon.sh --config $hadoop_conf_dir --script hdfs stop datanode

echo "start datanode"
$hadoop_distrib/sbin/hadoop-daemon.sh --config $hadoop_conf_dir --script hdfs start datanode

# start yarn
echo "start yarn"

echo "stop any running resourcemanager"
$hadoop_distrib/sbin/yarn-daemon.sh --config $hadoop_conf_dir stop resourcemanager

echo "stop any running nodemanager"
$hadoop_distrib/sbin/yarn-daemon.sh --config $hadoop_conf_dir stop nodemanager

#echo "stop any running jobhistoryserver"
#$hadoop_distrib/sbin/yarn-daemon.sh --config $hadoop_conf_dir stop historyserver

echo "start resourcemanager"
$hadoop_distrib/sbin/yarn-daemon.sh --config $hadoop_conf_dir start resourcemanager

echo "start nodemanager"
$hadoop_distrib/sbin/yarn-daemon.sh --config $hadoop_conf_dir start nodemanager


# hack wait for datanode to be ready and happy and able
sleep 10

## Upload Sample Data
#######################

# upload sample files
samplefile=sample-statuses-20120906-141433-medium.avro
$hadoop_distrib/bin/hadoop --config $hadoop_conf_dir fs -mkdir hdfs://127.0.0.1/indir
$hadoop_distrib/bin/hadoop --config $hadoop_conf_dir fs -put $samplefile hdfs://127.0.0.1/indir/$samplefile



## Start Solr
#######################

cd $solr_distrib

rm -r -f server2
rm -r -f server/solr/zoo_data
rm -r -f server/solr/collection1
rm -f server/server.log

#  tar -zxf
#unzip -o server/webapps/solr.war -d server/solr-webapp/webapp

# fix bad paths in release
sed -i -- 's/example/server/g' server/scripts/map-reduce/set-map-reduce-classpath.sh

cp -r -f server server2

# We are lazy and run ZooKeeper internally via Solr on shard1

# Bootstrap config files to ZooKeeper
echo "Upload config files to zookeeper..."
java -classpath "server/solr-webapp/webapp/WEB-INF/lib/*:server/lib/ext/*" org.apache.solr.cloud.ZkCLI -zkhost 127.0.0.1:9983 -cmd upconfig --confdir server/solr/configsets/basic_configs/conf --confname basic_configs -runzk 8983 -solrhome server/solr


echo "Starting Solr Server 1"
cd server
java -DSTOP.PORT=7983 -DSTOP.KEY=key -jar start.jar --module=http --stop 2>/dev/null
java -Xmx512m \
    -Djetty.port=8983 \
    -DzkRun \
    -DnumShards=2 \
    -Dsolr.directoryFactory=solr.HdfsDirectoryFactory \
    -Dsolr.lock.type=hdfs \
    -Dsolr.hdfs.home=hdfs://127.0.0.1:8020/solr1 \
    -Dsolr.hdfs.confdir=$hadoop_conf_dir \
    -DSTOP.PORT=7983 \
    -DSTOP.KEY=key \
    -jar start.jar \
    --module=http 1>server.log 2>&1 &

echo "Starting Solr Server 2"
cd ../server2
java -DSTOP.PORT=6574 -DSTOP.KEY=key -jar start.jar --module=http --stop 2>/dev/null
java -Xmx512m \
    -Djetty.port=7574 \
    -DzkHost=127.0.0.1:9983 \
    -DnumShards=2 \
    -Dsolr.directoryFactory=solr.HdfsDirectoryFactory \
    -Dsolr.lock.type=hdfs \
    -Dsolr.hdfs.home=hdfs://127.0.0.1:8020/solr2 \
    -Dsolr.hdfs.confdir=$hadoop_conf_dir \
    -DSTOP.PORT=6574 \
    -DSTOP.KEY=key \
    -jar start.jar \
    --module=http 1>server2.log 2>&1 &

# wait for solr to be ready
sleep 15

curl "127.0.0.1:8983/solr/admin/collections?action=CREATE&name=collection1&numShards=1&replicationFactor=1"

cd ../..

#
## Build an index with map-reduce and deploy it to SolrCloud
#######################
echo "Building solr index with map reduce"

source $solr_distrib/server/scripts/map-reduce/set-map-reduce-classpath.sh

$hadoop_distrib/bin/hadoop --config $hadoop_conf_dir \
  jar $solr_distrib/dist/solr-map-reduce-*.jar \
  -D 'mapred.child.java.opts=-Xmx500m' \
  -libjars "$HADOOP_LIBJAR" \
  --morphline-file readAvroContainer.conf \
  --zk-host 127.0.0.1:9983 \
  --output-dir hdfs://127.0.0.1:8020/outdir \
  --collection $collection \
  --log4j log4j.properties \
  --go-live \
  --verbose "hdfs://127.0.0.1:8020/indir"
