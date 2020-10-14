#!/usr/bin/perl

use Modern::Perl;
use C4::Context;
use Getopt::Long;

my $bibid;

GetOptions( 'b|bibid=s' => \$bibid, );

unless ($bibid) {
  die "ERROR: No --bibid (-b) defined";
}

my $query = "UPDATE aqorders SET biblionumber=? WHERE biblionumber IS NULL AND orderstatus = 'ordered'";
my $sth = C4::Context->dbh->prepare($query);
$sth->execute($bibid);

