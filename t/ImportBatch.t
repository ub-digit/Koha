#!/usr/bin/perl

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

use File::Temp qw|tempfile|;
use MARC::Field;
use MARC::File::XML;
use MARC::Record;
use Test::More tests => 4;
use t::lib::Mocks;

BEGIN {
    use_ok('C4::ImportBatch');
}

t::lib::Mocks::mock_preference('marcflavour', 'MARC21');

subtest 'StageFilterByUser' => sub {
    plan tests => 5;

    # Set current user to "user1"
    C4::Context->_new_userenv('USER1-ENV');
    C4::Context->set_userenv('12345', 'user1', '12345', '', '', '', '', 1, '', '');
    C4::Context->set_preference( 'StageFilterByUser', '1');
    C4::Context->set_preference( 'StageHideCleanedImported', '1');

    my $file = create_file({ two => 1, format => 'marc'});
    my ($errors, $recs) = C4::ImportBatch::RecordsFromISO2709File($file, 'biblio', 'UTF-8');

    my ($batch_id) = C4::ImportBatch::BatchStageMarcRecords('biblio', 'UTF-8', $recs,
                                                          'file1.mrc', undef, undef, '',
                                                          '', 1, 0, 0, undef);

    my $batch_list_user1 = C4::ImportBatch::GetImportBatchRangeDesc(0, 100000);
    is( find_id_in_batch_list($batch_id, $batch_list_user1), 1, "Found one batch from user1");

    # Set current user to "user2"
    C4::Context->_new_userenv('USER2-ENV');
    C4::Context->set_userenv('23456', 'user2', '23456', '', '', '', '', 1, '', '');

    my $batch_list_user2 = C4::ImportBatch::GetImportBatchRangeDesc(0, 100000);
    is( find_id_in_batch_list($batch_id, $batch_list_user2), 0, "Did not see batches from user1 when logged in as user2");

    $batch_list_user2 = C4::ImportBatch::GetImportBatchRangeDesc(0, 100000, 1);
    is( find_id_in_batch_list($batch_id, $batch_list_user2), 1, "Can see batch from user1 as user2 when filter is disabled");

    # Set current user back to "user1"
    C4::Context->_new_userenv('USER1-ENV');
    C4::Context->set_userenv('12345', 'user1', '12345', '', '', '', '', 1, '', '');

    C4::Context->set_preference( 'StageHideCleanedImported', '1');
    C4::ImportBatch::SetImportBatchStatus($batch_id, 'imported');

    $batch_list_user1 = C4::ImportBatch::GetImportBatchRangeDesc(0, 100000);
    is( find_id_in_batch_list($batch_id, $batch_list_user1), 0, "Did not see imported batch from user1 hen hidden");

    C4::Context->set_preference( 'StageHideCleanedImported', '0');
    C4::ImportBatch::SetImportBatchStatus($batch_id, 'imported');

    $batch_list_user1 = C4::ImportBatch::GetImportBatchRangeDesc(0, 100000);
    is( find_id_in_batch_list($batch_id, $batch_list_user1), 1, "Did see imported batch from user1 when not hidden");

    C4::ImportBatch::DeleteBatch($batch_id);
};

subtest 'RecordsFromISO2709File' => sub {
    plan tests => 4;

    my ( $errors, $recs );
    my $file = create_file({ whitespace => 1, format => 'marc' });
    ( $errors, $recs ) = C4::ImportBatch::RecordsFromISO2709File( $file, 'biblio', 'UTF-8' );
    is( @$recs, 0, 'No records from empty marc file' );

    $file = create_file({ garbage => 1, format => 'marc' });
    ( $errors, $recs ) = C4::ImportBatch::RecordsFromISO2709File( $file, 'biblio', 'UTF-8' );
    is( @$recs, 1, 'Garbage returns one record' );
    my @fields = @$recs? $recs->[0]->fields: ();
    is( @fields, 0, 'That is an empty record' );

    $file = create_file({ two => 1, format => 'marc' });
    ( $errors, $recs ) = C4::ImportBatch::RecordsFromISO2709File( $file, 'biblio', 'UTF-8' );
    is( @$recs, 2, 'File contains 2 records' );

};

subtest 'RecordsFromMARCXMLFile' => sub {
    plan tests => 3;

    my ( $errors, $recs );
    my $file = create_file({ whitespace => 1, format => 'marcxml' });
    ( $errors, $recs ) = C4::ImportBatch::RecordsFromMARCXMLFile( $file, 'UTF-8' );
    is( @$recs, 0, 'No records from empty marcxml file' );

    $file = create_file({ garbage => 1, format => 'marcxml' });
    ( $errors, $recs ) = C4::ImportBatch::RecordsFromMARCXMLFile( $file, 'UTF-8' );
    is( @$recs, 0, 'Garbage returns no records' );

    $file = create_file({ two => 1, format => 'marcxml' });
    ( $errors, $recs ) = C4::ImportBatch::RecordsFromMARCXMLFile( $file, 'UTF-8' );
    is( @$recs, 2, 'File has two records' );

};

sub create_file {
    my ( $params ) = @_;
    my ( $fh, $name ) = tempfile( SUFFIX => '.' . $params->{format} );
    if( $params->{garbage} ) {
        print $fh "Just some garbage\n\nAnd another line";
    } elsif( $params->{whitespace} ) {
        print $fh "  ";
    } elsif ( $params->{two} ) {
        my $rec1 = MARC::Record->new;
        my $rec2 = MARC::Record->new;
        my $fld1 = MARC::Field->new('245','','','a','Title1');
        my $fld2 = MARC::Field->new('245','','','a','Title2');
        $rec1->append_fields( $fld1 );
        $rec2->append_fields( $fld2 );
        if( $params->{format} eq 'marcxml' ) {
            my $str = $rec1->as_xml;
            # remove ending collection tag
            $str =~ s/<\/collection>//;
            print $fh $str;
            $str = $rec2->as_xml_record; # no collection tag
            # remove <?xml> line from 2nd record, add collection
            $str =~ s/<\?xml.*\n//;
            $str .= '</collection>';
            print $fh $str;
        } else {
            print $fh $rec1->as_formatted, "\x1D", $rec2->as_formatted;
        }
    }
    close $fh;
    return $name;
}

sub find_id_in_batch_list {
    my ($batch_id, $batch_list) = @_;
    my $found = 0;
    foreach my $batch (@$batch_list) {
        if($batch->{import_batch_id} == $batch_id) {
            $found = 1;
        }
    }
    return $found;
}
