#!/usr/bin/perl
#
# Copyright (C) 2011 Tamil s.a.r.l.
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use strict;
use warnings;

use Koha::Script;
use C4::Context;
use C4::Members::Messaging;
use Getopt::Long qw( GetOptions );
use Pod::Usage qw( pod2usage );
use Koha::MessageAttributes;

# Get the list ids of the relevant message names we want to sync
# This is stored in the syspref whichActionsToTickUsingSimpleMessaging
# The list of names is pipe separated
my $list_names = C4::Context->preference('whichActionsToTickUsingSimpleMessaging');
my @list_names = split(/\|/, $list_names);

my @list_ids;
foreach my $list_name (@list_names) {
    # Exclude Advance_Notice as we have already synced this
    next if $list_name eq 'Advance_Notice';
    my $list_id = Koha::MessageAttributes->search({ message_name => $list_name })->next->id;
    push @list_ids, $list_id;
}

sub usage {
    print "Usage: $0 --all --file=filename --borrower=1234 --commit\n";
    exit;
}

sub update_single_borrower {
    my ( $borrowernumber, $commit ) = @_;

    # Find the transport types for this borrower for Advance notices
    # Advance notices are the master for any other messaging preferences
    my $prefs = C4::Members::Messaging::GetMessagingPreferences( {
      borrowernumber => $borrowernumber, 
      message_name => 'Advance_Notice' 
    });

    # Extract transport types. Transports is a hashref of transport types
    # and we want the keys from the hashref as an array
    my @transports = keys %{$prefs->{transports}};
    # @transports = ["email", "sms"]

    # Now we have the transport types and the list ids we can update the
    # messaging preferences for this borrower.
    # This is done for each list id individually
    # Only do this if the --commit option is set
    if ($commit) {
        foreach my $list_id (@list_ids) {
            C4::Members::Messaging::SetMessagingPreference( {
                borrowernumber => $borrowernumber,
                message_attribute_id => $list_id,
                message_transport_types => \@transports,
                days_in_advance => 0,
                wants_digest => 0
            });
        }
    }
}

# Update all borrowers using update_single_borrower
sub update_all_borrowers {
    my $commit = shift;

    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT borrowernumber FROM borrowers");
    $sth->execute();

    while (my $borrowernumber = $sth->fetchrow_array) {
        update_single_borrower($borrowernumber, $commit);
    }
}

# Update borrowers from a file containing the borrowernumbers
# One borrowernumber per line
sub update_borrowers_from_file {
    my ($file, $commit) = @_;

    open my $fh, '<', $file or die "Can't open $file: $!";
    while (my $borrowernumber = <$fh>) {
        chomp $borrowernumber;
        update_single_borrower($borrowernumber, $commit);
    }
    close $fh;
}

my ( $commit, $all, $borrower, $file, $help );
my $result = GetOptions(
    'commit'      => \$commit,
    'all'         => \$all,
    'borrower:s'  => \$borrower,
    'file:s'      => \$file,
    'help|h'      => \$help,
);

usage() if $help;
usage() unless $all || $borrower || $file;
if($all) {
    update_all_borrowers($commit);
} elsif ($file) {
    update_borrowers_from_file($file, $commit);
} elsif ($borrower) {
    update_single_borrower($borrower, $commit);
}
