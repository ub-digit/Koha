#!/usr/bin/perl

use strict;
use warnings;

use Koha::Script -cron;
use C4::Context;
use Koha::Patrons;
use Modern::Perl;

my $weeks = shift @ARGV
    or die "Usage: $0 <weeks>\n";

die "Weeks must be a positive integer\n"
    unless $weeks =~ /^\d+$/;

my $dbh = C4::Context->dbh();

my $sth = $dbh->prepare("DELETE FROM deletedborrowers WHERE updated_on < DATE_SUB(NOW(), INTERVAL ? WEEK);");
my $res = $sth->execute($weeks);
