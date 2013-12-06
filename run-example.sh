#!/bin/bash

# EXAMPLE SCRIPT - Start hdfs, yarn, and solr - then build the indexes with mapreduce and deploy them to Solr
#
# Requires: Solr trunk Java 1.7+
#######################

# this gets hard coded in the configs - keep in sync
tmpdir=/tmp/solr-map-reduce

## Solr + Hadoop Dists
#######################

# Using a recent Solr nightly build from Solr trunk
solr_distrib="solr-5.0-2013-12-03_09-42-08"
solr_distrib_url="https://builds.apache.org/job/Solr-Artifacts-trunk/lastSuccessfulBuild/artifact/solr/package/$hadoop_distrib.tgz"

# you should replace with a local mirror. Find one at http://www.apache.org/dyn/closer.cgi/hadoop/common/hadoop-2.2.0/
hadoop_distrib="hadoop-2.2.0"
hadoop_distrib_url="http://www.eng.lsu.edu/mirrors/apache/hadoop/common/hadoop-2.2.0/$hadoop_distrib.tar.gz"

#########################################################
# NameNode port: 8020, DataNode ports: 50010, 50020, ResourceManager port: 8032 ZooKeeper port: 9983, Solr port: 8983
# NameNode web port: 50070, DataNodes web port: 50075
#########################################################


# collection to work with
collection=collection1


hadoop_conf="hadoop/conf"
hadoop_conf_dir="$tmpdir/hadoop/conf"

hadoopHome=`readlink -f "$hadoop_distrib"`
echo "HADOOP_HOME=$hadoopHome"
export HADOOP_HOME=$hadoopHome
export HADOOP_MAPRED_HOME=$hadoopHome
export HADOOP_COMMON_HOME=$hadoopHome
export HADOOP_HDFS_HOME=$hadoopHome
export YARN_HOME=$hadoopHome
export HADOOP_LOG_DIR=$tmpdir/logs
export HADOOP_CONF_DIR=$hadoop_conf_dir
export YARN_CONF_DIR=$hadoop_conf_dir
export YARN_COMMON_HOME=$hadoop_conf_dir

# clear any previous work
rm -f -r $tmpdir


# extract the hadoop conf files
tar -zxf "hadoop_conf.tar.gz"

# copy the hadoop conf files to the tmp dir
mkdir -p $tmpdir/hadoop
cp -r $hadoop_conf $hadoop_conf_dir


## Get Hadoop and Start HDFS+YARN
#######################

# get hadoop
if [ ! -f "$hadoop_distrib.tar.gz" ]; then
    echo "Download hadoop dist $hadoop_distrib.tar.gz"
    wget -q "$hadoop_distrib_url"

else
    echo "hadoop distrib already exists"
fi

# extract hadoop
if [ ! -d "$hadoop_distrib" ]; then
    tar -zxf "$hadoop_distrib.tar.gz"
else
    echo "$hadoop_distrib.tar.gz already extracted"
fi

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

#echo "start jobhistoryserver"
#$hadoop_distrib/sbin/yarn-daemon.sh --config $hadoop_conf_dir start historyserver

# hack wait for datanode to be ready and happy and able
sleep 10

## Upload Sample Data
#######################

# upload sample files
samplefile=sample-statuses-20120906-141433-medium.avro
$hadoop_distrib/bin/hadoop --config $hadoop_conf_dir fs -mkdir hdfs://127.0.0.1/indir
$hadoop_distrib/bin/hadoop --config $hadoop_conf_dir fs -put $samplefile hdfs://127.0.0.1/indir/$samplefile


## Get and Start Solr
#######################

# download solr
if [ ! -f "$solr_distrib.tgz" ]; then
    echo "Download hadoop dist $solr_distrib.tgz"
    wget -q "$solr_distrib_url"
else
    echo "solr distrib already exists"
fi

# extract solr
if [ ! -d "$solr_distrib" ]; then
    tar -zxf "$solr_distrib.tgz"
else
    echo "$solr_distrib.tgz already extracted"
fi

# start solr

# solr comes with collection1 preconfigured, so we juse use that rather than using the collections api
cd $solr_distrib

rm -r -f example2
rm -r -f example/solr/zoo_data
rm -r -f example/solr/collection1/data
rm -f example/example.log

unzip -o example/webapps/solr.war -d example/solr-webapp/webapp

echo "copy in twitter schema.xml file"
cp -f ../schema.xml example/solr/collection1/conf/schema.xml

cp -r -f example example2

# We are lazy and run ZooKeeper internally via Solr on shard1

# Bootstrap config files to ZooKeeper
java -classpath "example/solr-webapp/webapp/WEB-INF/lib/*:example/lib/ext/*" org.apache.solr.cloud.ZkCLI -cmd bootstrap -zkhost 127.0.0.1:9983 -solrhome example/solr -runzk 8983

cd example
java -DSTOP.PORT=7983 -DSTOP.KEY=key -jar start.jar --stop
java -DzkRun -DnumShards=2 -Dsolr.directoryFactory=solr.HdfsDirectoryFactory -Dsolr.lock.type=hdfs -Dsolr.hdfs.home=hdfs://127.0.0.1:8020/solr1 -Dsolr.hdfs.confdir=$hadoop_conf_dir -DSTOP.PORT=7983 -DSTOP.KEY=key -jar start.jar 1>example.log 2>&1 &

cd ../example2
java -DSTOP.PORT=6574 -DSTOP.KEY=key -jar start.jar --stop
java -Djetty.port=7574 -DzkHost=127.0.0.1:9983 -DnumShards=2 -Dsolr.directoryFactory=solr.HdfsDirectoryFactory -Dsolr.lock.type=hdfs -Dsolr.hdfs.home=hdfs://127.0.0.1:8020/solr2 -Dsolr.hdfs.confdir=$hadoop_conf_dir -DSTOP.PORT=6574 -DSTOP.KEY=key -jar start.jar 1>example2.log 2>&1 &

# wait for solr to be ready
sleep 15

cd ../..

# 
## Build an index with map-reduce and deploy it to SolrCloud
#######################

# we don't want to upload logging jars, let's just remove them for now
rm -f $solr_distrib/dist/solrj-lib/slf4j-*
rm -f $solr_distrib/dist/solrj-lib/log4j-*

# setup classpath
# @see {solr_dist}/example/scripts/map-reduce/set-map-reduce-classpath.sh (or similiar - file contents and name in flux)
dir1=`readlink -f "$solr_distrib/dist/*"`
dir2=`readlink -f "$solr_distrib/dist/solrj-lib/*"`
dir3=`readlink -f "$solr_distrib/contrib/map-reduce/lib/*"`
dir4=`readlink -f "$solr_distrib/contrib/morphlines-core/lib/*"`
dir5=`readlink -f "$solr_distrib/contrib/morphlines-cell/lib/*"`
dir6=`readlink -f "$solr_distrib/contrib/extraction/lib/*"`
dir7=`readlink -f "$solr_distrib/example/solr-webapp/webapp/WEB-INF/lib/*"`
echo "classpath: $dir1:$dir2:$dir3:$dir4:$dir5:$dir6:$dir7"
export HADOOP_CLASSPATH="$dir1:$dir2:$dir3:$dir4:$dir5:$dir6:$dir7"


lib1=`ls -m $dir1*.jar | tr -d ' \n'`
lib2=`ls -m $dir2*.jar | tr -d ' \n'`
lib3=`ls -m $dir3*.jar | tr -d ' \n'`
lib4=`ls -m $dir4*.jar | tr -d ' \n'`
lib5=`ls -m $dir5*.jar | tr -d ' \n'`
lib6=`ls -m $dir6*.jar | tr -d ' \n'`
lib7=`ls -m $dir7*.jar | tr -d ' \n'`

libjar="$lib1,$lib2,$lib3,$lib4,$lib5,$lib6,$lib7"

echo "libjar: $libjar"

$hadoop_distrib/bin/hadoop --config $hadoop_conf_dir jar $solr_distrib/dist/solr-map-reduce-5.0-SNAPSHOT.jar -D 'mapred.child.java.opts=-Xmx500m' -libjars "$libjar" --morphline-file readAvroContainer.conf --zk-host 127.0.0.1:9983 --output-dir hdfs://127.0.0.1:8020/outdir --collection $collection --log4j log4j.properties --go-live --verbose hdfs://127.0.0.1:8020/indir
