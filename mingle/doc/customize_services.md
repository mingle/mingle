Configure services by mingle.properties
===============================

Mingle need the following services:

* amq.broker: AcitveMQ Broker
* amq.nonblocking.broker: AcitveMQ Broker started in it's own thread, so that a slave broker will not block services start thread
* amq.connection.factory: Provide a ActiveMQ Connection Factory for other services and Mingle, should not remove this service
* amq.camel: AcitveMQ Camel server, multi-casting messages for Mingle events
* memcached: Memcached Server
* elastic_search: Elastic Search Server

By default, all of these services are launched by Mingle server.
However, when you need to configure a Mingle cluster, all of these services should only run on one Mingle node.
You can configure what's services are launched when Mingle starts by a JVM option:

    -Dmingle.services=amq.broker,amq.connection.factory,amq.camel,memcached,elastic_search

The services will be started by given order, so amq.broker will be started first and then amq.connection, etc.
Service amq.connection must be started after amq.broker and before all of other services.

For memcached server, there are some configurations can be changed by new Mingle properties:

    mingle.memcachedMaxSize       #maximum number of items allowed in the cache
    mingle.memcachedMaxBytes      #maximum size in bytes of the cache. default is 40 MB
    mingle.memcachedCeilingSize   #number of bytes to attempt to leave as ceiling room
    mingle.memcachedVerbose       #turn on verbose log if it is true
