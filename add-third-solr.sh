#!/bin/bash

# ADD THIRD SOLR - Demonstrates adding another Solr process, and it replicating data from and into HDFS.
#
#######################

solr_version="4.10.1"

# return absolute path
function absPath {
  echo $(cd $(dirname $1); pwd)/$(basename $1)
}

hadoop_conf_dir=`absPath "hadoop_conf/conf"`
echo "hadoop_conf: $hadoop_conf_dir"

cp -r -f solr-${solr_version}/example solr-${solr_version}/example3

cd solr-${solr_version}
cd example3
java -Xmx512m -Djetty.port=7575 -DzkHost=127.0.0.1:9983 -Dsolr.directoryFactory=solr.HdfsDirectoryFactory -Dsolr.lock.type=hdfs -Dsolr.hdfs.home=hdfs://127.0.0.1:8020/solr3 -Dsolr.hdfs.confdir=$hadoop_conf_dir -DSTOP.PORT=6575 -DSTOP.KEY=key -jar start.jar 1>example3.log 2>&1 &