#!/usr/bin/perl

use Modern::Perl;
use C4::Context;
use Getopt::Long;
use Pod::Usage;

my $gt_biblionumber;
my $help;
GetOptions(
    'gt_biblionumber=i' => \$gt_biblionumber,
    'batch_size=i' => \$batch_size,
    'h|help|?' => \$help
);
if ($help) {
    pod2usage(1);
}

my $dbh = C4::Context->dbh;
my $step = $batch_size || 25000;
my $offset = 0;
my $prev_biblionumber;
my ($max_biblionumber) = @{ $dbh->selectcol_arrayref(qq{SELECT MAX(`biblionumber`) FROM `biblio`}) };
my @ranges;
my $biblionumber;

while (1) {
    my $query = $gt_biblionumber ?
        qq{SELECT `biblionumber` FROM `biblio` WHERE `biblionumber` >= $gt_biblionumber ORDER BY `biblionumber` ASC LIMIT 1 OFFSET $offset} :
        qq{SELECT `biblionumber` FROM `biblio` ORDER BY `biblionumber` ASC LIMIT 1 OFFSET $offset};
    my ($biblionumber) = @{ $dbh->selectcol_arrayref($query) };
    if (!$biblionumber) {
        push @ranges, [$prev_biblionumber, $max_biblionumber];
        last;
    }
    elsif ($prev_biblionumber) {
        push @ranges, [$prev_biblionumber, $biblionumber - 1];
    }
    $prev_biblionumber = $biblionumber;
    $offset += $step;
}

foreach my $range (@ranges) {
    print join(' ', @{$range}) . "\n"; # @TODO: Option for argument and range separtor?
}

=head1 NAME

record batches - This script outputs ranges of biblionumbers

=head1 SYNOPSIS

record_batches.pl [-h|--help] [--gt_biblionumber=BIBLIONUMBER]

=head1 OPTIONS

=over

=item B<-h|--help>

Print a brief help message.

=item B<--gt_biblionumber>

 --gt_biblionumber=BIBLIONUMBER Output batches with biblionumber >= BIBLIONUMBER

=item B<--batch_size>

 --batch_size=BATCH_SIZE Set the batch size
