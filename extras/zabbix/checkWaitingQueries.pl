#!/usr/bin/perl

use DBI;
use strict;
use warnings;

# BEGIN CONF
## set up your limits here:

my $max_waiting = 100;

# set your host and db here.  Udeally use a .pgpass for authentication

my $host = 'localhost'; # hosts starting wtih / are paths to sockets
my $port = 5432;
my $db = 'postgres'; # doesn't matter since this is a db cluster global
my $dbuser = 'postgres';

# END CONF

my $dbh = DBI->connect("dbi:Pg:host=$host port=$port dbname=$db", $dbuser) or die 'No db connection';

my $sth = $dbh->prepare('select sum(count) from pgtelemetry.waiting_connections_by_event_type');
$sth->execute();
while (my ($count) = $sth->fetchrow_array){
    if ( defined $count and $count > $max_waiting){
        warn "Too many waiting queries";
        exit 1;
    }
}
exit 0;
       
