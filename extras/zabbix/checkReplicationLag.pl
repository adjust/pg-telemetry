#!/usr/bin/perl

use DBI;
use strict;
use warnings;

# BEGIN CONF
## set up your limits hash here:

my $max_lag_bytes = 1024 * 1024; #1MB

# set your host and db here.  Udeally use a .pgpass for authentication

my $host = 'localhost'; # hosts starting wtih / are paths to sockets
my $port = 5432;
my $db = 'postgres'; # doesn't matter since this is a db cluster global
my $dbuser = 'postgres';

# END CONF

my $dbh = DBI->connect("dbi:Pg:host=$host port=$port dbname=$db", $dbuser) or die 'No db connection';

my $sth = $dbh->prepare('select max(current_lag_bytes) from pgtelemetry.replication_slot_lag');
$sth->execute();
while (my $lag = $sth->fetchrow_array){
    if (defined $lag and $lag > $max_lag_bytes){
        warn "Replication lag limit $max_lag_bytes bytes exceeded";
        exit 1;
    }
}
exit 0;
       
