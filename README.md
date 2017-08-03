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

Currently this is expected to require PostgreSQL 9.6 and PostgreSQL 10 will be 
added in the near future.  However support for PostgreSQL instances before 9.6
is an area of interest and may be added anyway.

This module also requires that pg_stat_statements is installed.

## Documentation of monitoring

See the pgtelemetry.html in the doc folder.
