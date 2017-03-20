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
use Test::More tests => 1;
use Test::MockModule;
use Test::Warn;
use Test::WWW::Mechanize;
require HTTP::Request;
use MARC::Record;
use XML::Simple;
use C4::MarcModificationTemplates;
use C4::Biblio;

eval{
    use C4::Context;
};
if ($@) {
    plan skip_all => "Tests skip. You must have a working Context\n";
}

my $koha_conf = $ENV{KOHA_CONF};
my $koha_conf_xml = XMLin($koha_conf);

my $user     = $ENV{KOHA_USER} || $koha_conf_xml->{config}->{user};
my $password = $ENV{KOHA_PASS} || $koha_conf_xml->{config}->{pass};
my $intranet = $ENV{KOHA_INTRANET_URL};

if (not defined $intranet) {
    plan skip_all => "Tests skipped. You must set environment variable KOHA_INTRANET_URL to run tests\n";
}

subtest 'Templates applied using simple and advanced MARC Editor' => sub {
	plan tests => 13;

	# Create "Test" MARC modification template
    my $template_id = AddModificationTemplate('TEST');
    ok($template_id, 'MARC modification template successfully created');
    my $add_template_action_result = AddModificationTemplateAction(
        $template_id,
        'update_field', # Action
        0,
        250, # Field
        'a', # Subfield
        '251 bottles of beer on the wall', # Value
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        0,
        ''
    );
    ok($add_template_action_result, 'MARC modification template action successfully created');
    my $record =  MARC::Record->new();
    $record->leader('     nam a22     7a 4500');
	$record->append_fields(
		MARC::Field->new('001', '12345'),
		MARC::Field->new('003', 'TEST'),
		MARC::Field->new('245', '1', '0', 'a' => 'TEST'),
		MARC::Field->new('250', '','', 'a' => '250 bottles of beer on the wall'),
        # @FIXME: Create test item type? Not super safe to rely on existing 'BK' type
		MARC::Field->new('942', '','', 'c' => 'BK'),
	);
    my ($biblionumber) = AddBiblio($record, '');

    my $saved_record = GetMarcBiblio($biblionumber, 0);
    my $saved_record_250_field = $saved_record->field('250');
    isa_ok($saved_record_250_field, 'MARC::Field', 'Field with tag 250 has been saved');
    is($saved_record_250_field->subfield('a'), '250 bottles of beer on the wall', 'Field 250a has the same value passed to AddBiblio');

    my $old_template_preference = C4::Context->preference('EditBiblioMarcModificationTemplate');
    C4::Context->set_preference('EditBiblioMarcModificationTemplate', 'TEST');

    my $agent = Test::WWW::Mechanize->new(autocheck => 1);

    $agent->get_ok("$intranet/cgi-bin/koha/mainpage.pl", 'Connect to intranet');
    $agent->form_name('loginform');
    $agent->field('password', $password);
    $agent->field('userid', $user);
    $agent->field('branch', '');
    $agent->click_ok('', 'Login to staff client');

    $agent->get_ok("$intranet/cgi-bin/koha/mainpage.pl", 'Load main page'); #FIXME: Remove?
    $agent->get_ok("$intranet/cgi-bin/koha/cataloguing/addbiblio.pl?biblionumber=$biblionumber", 'Load bibliographic record in simple MARC editor');
    $agent->submit_form_ok(
        {
            form_id => 'f',
            button => '',
        },
        'Save bibliographic record using simple MARC editor'
    );

    $saved_record = GetMarcBiblio($biblionumber, 0);
    $saved_record_250_field = $saved_record->field('250');
    is($saved_record_250_field->subfield('a'), '251 bottles of beer on the wall', 'Field with tag 250 has been modified by MARC modification template');

    # FIXME: Don't really need to to this, but could be useful so
    # test below does not succed by accident
    $saved_record->delete_fields($saved_record_250_field);
    $saved_record->insert_fields_ordered(MARC::Field->new('250', '','', 'a' => '250 bottles of beer on the wall'));
    $biblionumber = ModBiblioMarc($saved_record, $biblionumber);
    ok($biblionumber, 'Field with tag 250 has been restored to original value');

    # @FIXME: Leader record status n or c?
    my $record_xml = <<'EOF';
<?xml version="1.0" standalone='yes'?>
    <record xmlns="http://www.loc.gov/MARC21/slim">
        <leader>     cam a22     7a 4500</leader>
        <controlfield tag="001">12345</controlfield>
        <controlfield tag="003">TEST</controlfield>
        <datafield tag="245" ind1="1" ind2="0">
            <subfield code="a">TEST</subfield>
        </datafield>
        <datafield tag="250" ind1=" " ind2=" ">
            <subfield code="a">250 bottles of beer on the wall</subfield>
        </datafield>
        <datafield tag="942" ind1=" " ind2=" ">
            <subfield code="c">BK</subfield>
            <subfield code="2">ddc</subfield>
        </datafield></record>
EOF
    my $headers = HTTP::Headers->new(
        Content_Type => 'text/xml',
    );
    my $request = HTTP::Request->new('POST', "$intranet/cgi-bin/koha/svc/bib/$biblionumber", $headers, $record_xml);
    my $response = $agent->request($request);

    is($response->code, '200', 'Emulate save in advanced MARC editor, Koha REST API responded with 200 for update biblio request');
    like($response->decoded_content, qr/251 bottles of beer on the wall/, 'Field with tag 250 has been modified by MARC modification template');

    # Clean up
    DelBiblio($biblionumber);
    DelModificationTemplate($template_id);
    C4::Context->set_preference('EditBiblioMarcModificationTemplate', $old_template_preference);
};
