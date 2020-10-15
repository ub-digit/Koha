#! /usr/bin/perl

use Modern::Perl;
use C4::Context;
use Getopt::Long;
use DateTime;
use Koha::Items;

my $newlostvalue;
my $dt;

GetOptions( 'tovalue=i' => \$newlostvalue, );

unless ($newlostvalue) {
  die "ERROR: No -tovalue defined";
}

my $query = "SELECT itemnumber FROM items WHERE itemlost=2 AND itemnumber NOT IN (SELECT itemnumber FROM issues)";
my $sth = C4::Context->dbh->prepare($query);
$sth->execute();
while (my $itemnumber = $sth->fetchrow_array) {
  my $item = Koha::Items->find($itemnumber);
  $dt = DateTime->now;
  $item->itemlost($newlostvalue);
  $item->itemlost_on($dt);
  $item->store();
  print "New lost value $newlostvalue for item $itemnumber at $dt\n";
}
