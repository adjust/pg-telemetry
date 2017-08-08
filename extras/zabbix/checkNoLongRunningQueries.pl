#!/usr/bin/perl

use DBI;
use strict;
use warnings;

# BEGIN CONF
## set up your limits here:

my $max_duration = '900'; # in seconds

# set your host and db here.  Udeally use a .pgpass for authentication

my $host = 'localhost'; # hosts starting wtih / are paths to sockets
my $port = 5432;
my $db = 'postgres'; # doesn't matter since this is a db cluster global
my $dbuser = 'postgres';

# END CONF

my $dbh = DBI->connect("dbi:Pg:host=$host port=$port dbname=$db", $dbuser) or die 'No db connection';

my $sth = $dbh->prepare('select extract(epoch from max(running_for)) as secs from pgtelemetry.longest_running_active_queries');
$sth->execute();
while (my $row = $sth->fetchrow_hashref('NAME_lc')){
    if ($row->{secs} > $max_duration){
       warn "Query running duration exceeded maximum duration of $max_duration";
       exit 1;
    }
}
exit 0;
       
