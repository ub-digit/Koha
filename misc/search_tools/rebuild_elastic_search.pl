#!/usr/bin/perl

# This inserts records from a Koha database into elastic search

# Copyright 2014 Catalyst IT
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

=head1 NAME

rebuild_elastic_search.pl - inserts records from a Koha database into Elasticsearch

=head1 SYNOPSIS

B<rebuild_elastic_search.pl>
[B<-c|--commit>=C<count>]
[B<-v|--verbose>]
[B<-h|--help>]
[B<--man>]

=head1 DESCRIPTION

Inserts records from a Koha database into Elasticsearch.

=head1 OPTIONS

=over

=item B<-c|--commit>=C<count>

Specify how many records will be batched up before they're added to Elasticsearch.
Higher should be faster, but will cause more RAM usage. Default is 5000.

=item B<-d|--delete>

Delete the index and recreate it before indexing.

=item B<-a|--authorities>

Index the authorities only. Combining this with B<-b> is the same as
specifying neither and so both get indexed.

=item B<-b|--biblios>

Index the biblios only. Combining this with B<-a> is the same as
specifying neither and so both get indexed.

=item B<-bn|--bnumber>

Only index the supplied biblionumber, mostly for testing purposes. May be
repeated. This also applies to authorities via authid, so if you're using it,
you probably only want to do one or the other at a time.

=item B<-Q|--queue>

Reindex items stored in zebraqueue only. Indexed items will be removed when indexed.
If used with --authorities or --biblios, they act as filters on the zebraqueue.
Using --bnumber has no relevance with queue and will be ignored.
Any use of --delete will also be ignored.

=item B<-n|--concurrent>=C<count>

Only available with -Q.
If number of posts in zebraqueue with "done=2" is higher than <commit>*<concurrent>,
there are already things running. Exit this process if so.
TODO: Make better handling in case there are leftover rows in the table.

Reindex items stored in zebraqueue only. Indexed items will be removed when indexed.
If used with --authorities or --biblios, they act as filters on the zebraqueue.
Using --bnumber has no relevance with queue and will be ignored.
Any use of --delete will also be ignored.

=item B<-v|--verbose>

By default, this program only emits warnings and errors. This makes it talk
more. Add more to make it even more wordy, in particular when debugging.

=item B<-h|--help>

Help!

=item B<--man>

Full documentation.

=back

=cut

use autodie;
use Getopt::Long;
use C4::Context;
use Koha::MetadataRecord::Authority;
use Koha::BiblioUtils;
use Koha::SearchEngine::Elasticsearch::Indexer;
use MARC::Field;
use MARC::Record;
use Modern::Perl;
use Pod::Usage;

my $verbose = 0;
my $commit = 5000;
my $concurrent = 1;
my ($delete, $help, $man);
my ($index_biblios, $index_authorities, $index_queue);
my (@biblionumbers);
my $dbh;

$|=1; # flushes output

GetOptions(
    'c|commit=i'       => \$commit,
    'd|delete'         => \$delete,
    'a|authorities' => \$index_authorities,
    'b|biblios' => \$index_biblios,
    'bn|bnumber=i' => \@biblionumbers,
    'n|concurrent=i'   => \$concurrent,
    'Q|queue'          => \$index_queue,
    'v|verbose+'       => \$verbose,
    'h|help'           => \$help,
    'man'              => \$man,
);

# Default is to do both
unless ($index_authorities || $index_biblios) {
    $index_authorities = $index_biblios = 1;
}

if($index_queue) {
    $delete = 0;
}

pod2usage(1) if $help;
pod2usage( -exitstatus => 0, -verbose => 2 ) if $man;

sanity_check();

my $next;
if ($index_biblios && !$index_queue) {
    _log(1, "Indexing biblios\n");
    if (@biblionumbers) {
        $next = sub {
            my $r = shift @biblionumbers;
            return () unless defined $r;
            return ($r, Koha::BiblioUtils->get_from_biblionumber($r, item_data => 1 ));
        };
    } else {
        my $records = Koha::BiblioUtils->get_all_biblios_iterator();
        $next = sub {
            $records->next();
        }
    }
    do_reindex($next, $Koha::SearchEngine::Elasticsearch::BIBLIOS_INDEX);
}
if ($index_authorities && !$index_queue) {
    _log(1, "Indexing authorities\n");
    if (@biblionumbers) {
        $next = sub {
            my $r = shift @biblionumbers;
            return () unless defined $r;
            my $a = Koha::MetadataRecord::Authority->get_from_authid($r);
            return ($r, $a->record);
        };
    } else {
        my $records = Koha::MetadataRecord::Authority->get_all_authorities_iterator();
        $next = sub {
            $records->next();
        }
    }
    do_reindex($next, $Koha::SearchEngine::Elasticsearch::AUTHORITIES_INDEX);
}
if ($index_queue) {
    $dbh = C4::Context->dbh;

    # Exit if there are too many concurrent records in progress already.
    if(is_past_concurrency_limit()) {
        _log(1, "Too many records in progress already.\n");
        exit(0);
    }

    if($index_biblios) {
        _log(1, "Indexing queued bibliographic records.\n");
        my ($ids, $record_ids, $records) = fetch_queued_records({biblios => $index_biblios});
        my $count = do_queued_reindex($ids, $record_ids, $records, $Koha::SearchEngine::Elasticsearch::BIBLIOS_INDEX);
        mark_ids_as_done($ids);
        _log(1, "Indexed $count queued bibliographic records.\n");
    }
    if($index_authorities) {
        _log(1, "Indexing queued authority records.\n");
        my ($ids, $record_ids, $records) = fetch_queued_records({authorities => $index_authorities});
        my $count = do_queued_reindex($ids, $record_ids, $records, $Koha::SearchEngine::Elasticsearch::AUTHORITIES_INDEX);
        mark_ids_as_done($ids);
        _log(1, "Indexed $count queued authority records.\n");
    }
}

sub do_reindex {
    my ( $next, $index_name ) = @_;

    my $indexer = Koha::SearchEngine::Elasticsearch::Indexer->new( { index => $index_name } );

    if ($delete) {
        $indexer->drop_index() if $indexer->index_exists();
        $indexer->create_index();
    }
    elsif (!$indexer->index_exists) {
        # Create index if does not exist
        $indexer->create_index();
    } elsif ($indexer->is_index_status_ok) {
        # Update mapping unless index is some kind of problematic state
        $indexer->update_mappings();
    } elsif ($indexer->is_index_status_recreate_required) {
        warn qq/Index "$index_name" has status "recreate required", suggesting it should be recreated/;
    }

    my $count        = 0;
    my $commit_count = $commit;
    my ( @id_buffer, @commit_buffer );
    while ( my $record = $next->() ) {
        my $id     = $record->id;
        my $record = $record->record;
        $count++;
        if ( $verbose == 1 ) {
            _log( 1, "$count records processed\n" ) if ( $count % 1000 == 0);
        } else {
            _log( 2, "$id\n" );
        }

        push @id_buffer,     $id;
        push @commit_buffer, $record;
        if ( !( --$commit_count ) ) {
            _log( 1, "Committing $commit records..." );
            $indexer->update_index( \@id_buffer, \@commit_buffer );
            $commit_count  = $commit;
            @id_buffer     = ();
            @commit_buffer = ();
            _log( 1, " done\n" );
        }
    }

    # There are probably uncommitted records
    _log( 1, "Committing final records...\n" );
    $indexer->update_index( \@id_buffer, \@commit_buffer );
    _log( 1, "Total $count records indexed\n" );
}

# Do queued reindex. This is based off an id list, not an iterator
sub do_queued_reindex {
    my ($ids, $record_ids, $records, $index_name) = @_;
    my $indexer = Koha::SearchEngine::Elasticsearch::Indexer->new( { index => $index_name } );
    my $count = @{$ids};

    $indexer->update_index($record_ids, $records);

    return $count;
}


# Checks some basic stuff to ensure that it's sane before we start.
sub sanity_check {
    # Do we have an elasticsearch block defined?
    my $conf = C4::Context->config('elasticsearch');
    die "No 'elasticsearch' block is defined in koha-conf.xml.\n" if ( !$conf );
}

# Output progress information.
#
#   _log($level, $msg);
#
# Will output $msg if the verbosity setting is set to $level or more. Will
# not include a trailing newline.
sub _log {
    my ($level, $msg) = @_;

    print $msg if ($verbose >= $level);
}

# Fetch record ids from zebraqueue, filtered if necessary
# Record ids that were fetched gets their done value set to 2,
# which will indicate a "being processed" state.
# Once all fetched records are indexed, done values will be set to 1.
# This makes identifying missed batches easier, and will prevent multiple
# runs of the same script from indexing the same records.
# TODO: Handle cleanup of rows with done == 2
sub fetch_queued_records {
    my ($params) = @_;
    my @conditions = ();
    my @bind_params = ();

    if($params->{biblios}) {
        push(@conditions, "server = ?");
        push(@bind_params, "biblioserver");
    } elsif($params->{authorities}) {
        push(@conditions, "server = ?");
        push(@bind_params, "authorityserver");
    }

    my $query = "SELECT id, biblio_auth_number
                             FROM zebraqueue
                             WHERE done = 0
                             AND operation = 'specialUpdate'";
    if(@conditions) {
        $query .= " AND ";
    }
    $query .= join(" AND ", @conditions);
    $query .= " ORDER BY id DESC";
    $query .= " LIMIT ?";

    # Add commit count as limit
    push(@bind_params, $commit);

    my $sth = $dbh->prepare($query);
    $sth->execute(@bind_params);
    my $entries = $sth->fetchall_arrayref({});
    $sth->finish();

    my @ids = ();
    # Extract queue-ids from result before fetching records.
    foreach my $entry (@{$entries}) {
        push(@ids, $entry->{id});
    }

    if(!@ids) {
        return ([], [], []);
    }

    # Mark fetched items
    my $id_str = join(",", @ids);
    $sth = $dbh->prepare("UPDATE zebraqueue SET done = 2 WHERE id IN (".$id_str.")");
    $sth->execute();
    $sth->finish();

    my @record_ids = ();
    my @records = ();
    foreach my $entry (@{$entries}) {
        my $record_id = $entry->{biblio_auth_number};
        push(@record_ids, $record_id);

        if($params->{biblios}) {
            my $r = Koha::BiblioUtils->get_from_biblionumber($record_id, item_data => 1 );
            push(@records, $r->record);
        }
        if($params->{authorities}) {
            my $r = Koha::MetadataRecord::Authority->get_from_authid($record_id);
            push(@records, $r->record);
        }
    }

    return (\@ids, \@record_ids, \@records);
}

# Remove records from zebraqueue, after indexing has been performed.
# NOTE! This is zebraqueue id's, not biblio_auth_number
sub mark_ids_as_done {
    my ($ids) = @_;
    my $id_str = join(",", @{$ids});
    if(!$id_str) {
        return;
    }

    my $query = "UPDATE zebraqueue SET done = 1 WHERE id IN (".$id_str.")";

    my $sth = $dbh->prepare($query);
    $sth->execute();
    $sth->finish();
}

# Check if there are too many records in progress already.
# TRUE if too many, FALSE if not.
sub is_past_concurrency_limit {
    my $sth = $dbh->prepare("SELECT COUNT(*) FROM zebraqueue WHERE done = 2");
    $sth->execute();
    my $count = $sth->fetchall_arrayref->[0]->[0];
    $sth->finish();
    if($count >= ($commit * $concurrent)) {
        return 1;
    } else {
        return 0;
    }
}
