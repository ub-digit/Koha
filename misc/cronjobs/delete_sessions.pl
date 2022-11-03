#!/usr/bin/perl

use strict;
use warnings;

use Modern::Perl;
use Koha::Script -cron;
use C4::Context;

my $dbh = C4::Context->dbh();

my $sth = $dbh->prepare("TRUNCATE TABLE sessions");
my $res = $sth->execute();
