#!/usr/bin/perl

use strict;
use warnings;

use Koha::Script -cron;
use C4::Context;
use Koha::Patrons;
use Modern::Perl;

my $dbh = C4::Context->dbh();

my $sth = $dbh->prepare("DELETE FROM deletedborrowers WHERE updated_on < DATE_SUB(NOW(), INTERVAL 1 WEEK);");
my $res = $sth->execute();
