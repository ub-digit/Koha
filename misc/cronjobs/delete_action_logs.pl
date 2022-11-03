#!/usr/bin/perl

use strict;
use warnings;

use Modern::Perl;
use Koha::Script -cron;
use C4::Context;
use Getopt::Long qw( GetOptions );
use POSIX qw(strftime);

my $preservedays;

GetOptions(
    'd|preservedays:i' => \$preservedays,
);

my $usage = "Enter number of days that will be preserved by using the -d flag\n";

unless ($preservedays) {
    print $usage;
    exit;
}

my $dbh = C4::Context->dbh();
my $sth = $dbh->prepare("DELETE FROM action_logs WHERE timestamp < DATE_SUB(NOW(), INTERVAL $preservedays DAY)");
my $res = $sth->execute();
my $rows = $sth->rows;
my $now = strftime('%Y-%m-%d %H:%M:%S',localtime);
print "$now : $rows number of rows deleted from action_logs\n";