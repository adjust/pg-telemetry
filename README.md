[![TEST](https://github.com/adjust/pg-telemetry/actions/workflows/test.yml/badge.svg)](https://github.com/adjust/pg-telemetry/actions/workflows/test.yml)


# pg_telemetry, an extension for getting usage states from PostgreSQL

Welcome to pg_telemetry, an extension for monitoring usage of PostgreSQL.

This module provides functions for deriving usage stats from system stats
and other system administration functions.  It aims to provide a generally
useful and reusable series of metrics functions for monitoring purposes.

Most of the data is set to export numbers and can be used to supply SNMP
agents, Zabbix agents, and other monitoring programs with data.

## Intended Usage

The module is intended to be used with monitoring and visualizaiton
programs such as pganalyze, zabbix, and munin.  These tend to use an agent
which collects performance data and sends it to a server for graphics
generation.  Some of the functions here are wrapped in views.

A second class of functions are in place for administrators to use in
troubleshooting and debugging performance issues.  However these are to be
used as needed while the general stats functions are assumed to be run
every few min at least.

We expect this extension usually to be installed in its own schema.
However, it can be safely installed anywhere its names don't conflict
with anything else.

## Areas of focus

In the initial phase, there are several areas of focus for this project:

 * Disk usage
 * Sources of concurrent queries
 * WAL throughput
 * Replication Monitoring

## Requirements

Currently this is expected to require PostgreSQL 10+.

This module also requires that pg_stat_statements is installed.

## Documentation of monitoring views, relations, and functions

See the [pgtelemetry.html](doc/pgtelemetry.html) in the doc folder.

## Installation

pg_stats_statements must be installed and preloaded.  Once that is the case,
you can use the standard make/make install process to install this extension:

    make install

That copies the files into the PostgreSQL extensions directory.  In some
cases (Windows) you may need to install appropriate development tools
such as MinGW and on Linux in some cases you may need the development
libraries.

After that, in the database you want to base your monitoring on:

    create extension pgtelemetry;

This will create the pgtelemetry schema and place all the objects there.

## Extras

In the extras directory there are a number of important integration examples.

extras/prometheus:

   * queries.yaml includes a basic yaml for pulling stats into Prometheus
   * queries_wal.yaml is a basic wal telemetry yaml that can be run on
master databasess

extras/zabbix:

   * checkTablespaceSize.pl raises an alarm if any tablespace is too big
   * checkNoLongRunningQueries.pl raises an alarm if queries have been
     running too long.
   * checkWaitingQueries.pl raises an alarm if too many queries are
     waiting on locks and latches.
   * checkReplicationLag.pl raises an alarm if replication lag is too
     high (checks downstream).

What is too big?  To high?  Too long?  These are set in the beginning
of the scripts making this easy to integrate with Zabbix.
