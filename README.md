solr-map-reduce-example
=======================

This project is meant to provide an example of how to build Solr indexes with MapReduce.

The main part is the script called run-example. This script will download hadoop and solr and start both them. It will then run a mapreduce job and build an index from the included sample twitter data. Finally, the indexes will be deployed to the Solr cluster via the GoLive feature.

The script is meant as both a way to quickly see something working and as a reference for building Solr indexes on your real Hadoop cluster.

This is not an example of good production settings! This setup is meant for a single node demo system.

Running the Example
----------------------

Download the repository files using the 'Download ZIP' button and extract them to a new directory. From that directory, run the included run-example.sh script and sit back and watch.
    
      bash run-example.sh


Web URLs
----------------------
Solr http://127.0.0.1:8983/solr
NameNode http://127.0.0.1:50075
Yarn http://127.0.0.1:8042

