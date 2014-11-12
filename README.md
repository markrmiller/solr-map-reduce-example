solr-map-reduce-example
=======================

This project is meant to provide an example of how to build Solr indexes with MapReduce.

The main part is the script called run-example. This script will download Hadoop and Solr and start both of them. It will then run a map-reduce job and build an index from the included sample twitter data. Finally, the indexes will be deployed to the Solr cluster via the GoLive feature.

The script is meant as both a way to quickly see something working and as a reference for building Solr indexes on your real Hadoop cluster.

This is not an example of good production settings! This setup is meant for a single node demo system.

Running the Example
----------------------

Download the repository files using the 'Download ZIP' button and extract them to a new directory. From that directory, run the included run-example.sh script and sit back and watch.
    
      bash run-example.sh


Stopping the Example
----------------------

Run the included stop script.

      bash stop-example.sh


Files
----------------------

run-example.sh - the main script that downloads and runs everything

stop-example.sh - a script to stop the services started by run-example.sh

log4j.properties - the log4j config file attached to the map-reduce job

readAvroContainer.conf - a Morphline for reading avro files

sample-statuses-20120906-141433-medium.avro - sample Twitter format data

schema.xml - a schema for the sample Twitter formated data


Software Versions
----------------------

This is currently using:

Hadoop 2.2.0

Solr 4.10.1


Web URLs
----------------------

Solr http://127.0.0.1:8983/solr
NameNode http://127.0.0.1:50075
Yarn http://127.0.0.1:8042


Links
----------------------

Running Solr on HDFS - https://cwiki.apache.org/confluence/display/solr/Running+Solr+on+HDFS

Morphlines - http://kitesdk.org/docs/current/kite-morphlines/index.html


Errata
----------------------

Most logs and files will be created in /tmp/solr-map-reduce - anything not found there should be under the Solr-map-reduce-example directory itself.

There are two inefficient waits in the script - after we start HDFS and after we start Solr, we naively wait.

