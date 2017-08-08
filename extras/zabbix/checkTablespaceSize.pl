#!/usr/bin/perl

use DBI;
use strict;
use warnings;

# BEGIN CONF
## set up your limits hash here:

my %tslimits = (
   pg_default => 1024^4, # 1TB  
);

# set your host and db here.  Udeally use a .pgpass for authentication

my $host = 'localhost'; # hosts starting wtih / are paths to sockets
my $port = 5432;
my $db = 'postgres'; # doesn't matter since this is a db cluster global
my $dbuser = 'postgres';

# END CONF

my $dbh = DBI->connect("dbi:Pg:host=$host port=$port dbname=$db", $dbuser) or die 'No db connection';

my $sth = $dbh->prepare('select name, bytes from pgtelemetry.tablespace_size');
$sth->execute();
while (my $row = $sth->fetchrow_hashref('NAME_lc')){
    if (exists $tslimits{$row->{name}} and $tslimits{$row->{name}} > $row->{bytes} ){
        warn "Tablespace $row->{name} is above limit";
        exit 1;
    }
}
exit 0;
       
