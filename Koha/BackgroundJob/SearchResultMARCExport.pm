package Koha::BackgroundJob::SearchResultMARCExport;

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

use Modern::Perl;
use Try::Tiny;
use Koha::SearchEngine::Search;

use File::Spec;
use File::Path qw(mkpath);
use Koha::Email;
use Koha::UploadedFiles;
use POSIX qw(strftime);
use Digest::MD5 qw(md5_hex);
use Carp qw(croak);

use base 'Koha::BackgroundJob';

=head1 NAME

Koha::BackgroundJob::SearchResultMARCExport - Export MARC records from search result

This is a subclass of Koha::BackgroundJob.

=head1 API

=head2 Class methods

=head3 job_type

Define the job type of this job: stage_marc_for_import

=cut

sub job_type {
    return 'search_result_marc_export';
}

=head3 process

Stage the MARC records for import.

=cut

sub process {
    my ( $self, $args ) = @_;

    $self->start;

    my $data = $self->decoded_data;
    my $borrowernumber = $data->{borrowernumber};
    my $elasticsearch_query = $args->{elasticsearch_query};
    my $preferred_format = $args->{preferred_format};
    my $searcher = Koha::SearchEngine::Search->new({
        index => $Koha::SearchEngine::BIBLIOS_INDEX
    });
    my $elasticsearch = $searcher->get_elasticsearch();

    my $results = eval {
        $elasticsearch->search(
            index => $searcher->index_name,
            scroll => '1m', #TODO: Syspref for scroll time limit?
            size => 1000,  #TODO: Syspref for batch size?
            body => $elasticsearch_query
        );
    };
    my @errors;
    push @errors, $@ if $@;

    my @docs;
    my $encoded_results;
    my %export_links;
    my $query_string = $elasticsearch_query->{query}->{query_string}->{query};

    if (!@errors) {
        my $scroll_id = $results->{_scroll_id};
        while (@{$results->{hits}->{hits}}) {
            push @docs, @{$results->{hits}->{hits}};
            $self->progress( $self->progress + scalar @{$results->{hits}->{hits}} )->store;
            $results = $elasticsearch->scroll(
                scroll => '1m',
                scroll_id => $scroll_id
            );
        }

        if ($preferred_format eq 'ISO2709' || $preferred_format eq 'MARCXML') {
            $encoded_results = $searcher->search_documents_encode(\@docs, $preferred_format);
        }
        else {
            $encoded_results->{$preferred_format->{name}} =
                $searcher->search_documents_custom_format_encode(\@docs, $preferred_format);
        }

        my %format_extensions = (
            'ISO2709' => '.mrc',
            'MARCXML' => '.xml',
        );

        my $upload_dir = Koha::UploadedFile->permanent_directory;

        while (my ($format, $data) = each %{$encoded_results}) {
            my $hash = md5_hex($data);
            my $category = "search_marc_export";
            my $time = strftime "%Y%m%d_%H%M", localtime time;
            my $ext = exists $format_extensions{$format} ? $format_extensions{$format} : '.txt';
            my $filename = $category . '_' . $time . $ext;
            my $file_dir = File::Spec->catfile($upload_dir, $category);
            if ( !-d $file_dir) {
                unless(mkpath $file_dir) {
                    push @errors, "Failed to create $file_dir";
                    next;
                }
            }
            my $filepath = File::Spec->catfile($file_dir, "${hash}_${filename}");

            my $fh = IO::File->new($filepath, "w");

            if ($fh) {
                $fh->binmode;
                print $fh $data;
                $fh->close;

                my $size = -s $filepath;
                my $file = Koha::UploadedFile->new({
                        hashvalue => $hash,
                        filename  => $filename,
                        dir       => $category,
                        filesize  => $size,
                        owner     => $borrowernumber,
                        uploadcategorycode => 'search_marc_export',
                        public    => 0,
                        permanent => 1,
                    })->store;
                my $id = $file->_result()->get_column('id');
                $export_links{$format} = "/cgi-bin/koha/tools/upload.pl?op=download&id=$id";
            }
            else {
                push @errors, "Failed to write \"$filepath\"";
            }
        }
    }
    my $report = {
        export_links => \%export_links,
        total => scalar @docs,
        errors => \@errors,
        query_string => $query_string,
    };
    $data->{report}   = $report;
    if (@errors) {
        $self->set({ progress => 0, status => 'failed' })->store;
    }
    else {
        $self->finish($data);
    }
}

=head3 enqueue

Enqueue the new job

=cut

sub enqueue {
    my ( $self, $args) = @_;
    $self->SUPER::enqueue({
        job_size => $args->{size},
        job_args => $args,
        job_queue => 'long_tasks',
    });
}

1;
