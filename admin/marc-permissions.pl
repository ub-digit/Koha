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

use strict;
use warnings;

# standard or CPAN modules used
use CGI qw ( -utf8 );
use CGI::Cookie;
use MARC::File::USMARC;

# Koha modules used
use C4::Context;
use C4::Koha;
use C4::Auth;
use C4::AuthoritiesMarc;
use C4::Output;
use C4::Biblio;
use C4::ImportBatch;
use C4::Matcher;
use C4::BackgroundJob;
use C4::Labels::Batch;

my $script_name = "/cgi-bin/koha/admin/marc-permissions.pl";

my $input = new CGI;
my $op = $input->param('op') || '';

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "admin/marc-permissions.tt",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { parameters => 'parameters_remaining_permissions' },
        debug           => 1,
    }
);

my %cookies = parse CGI::Cookie($cookie);
our $sessionID = $cookies{'CGISESSID'}->value;

my $rules;
if ( $op eq "remove" ) {
    $template->{VARS}->{removeConfirm} = 1;
    my @removeIDs = $input->multi_param('batchremove');
    push( @removeIDs, scalar $input->param('id') ) if $input->param('id');

    $rules = GetMarcPermissionsRules();
    for my $removeID (@removeIDs) {
        map { $_->{'remove'} = 1 if $_->{'id'} == $removeID } @{$rules};
    }

}
elsif ( $op eq "doremove" ) {
    my @removeIDs = $input->multi_param('batchremove');
    push( @removeIDs, scalar $input->param('id') ) if $input->param('id');
    for my $removeID (@removeIDs) {
        DelMarcPermissionsRule($removeID);
    }

    $rules = GetMarcPermissionsRules();

}
elsif ( $op eq "edit" ) {
    $template->{VARS}->{edit} = 1;
    my $id = $input->param('id');
    $rules = GetMarcPermissionsRules();
    map { $_->{'edit'} = 1 if $_->{'id'} == $id } @{$rules};

}
elsif ( $op eq "doedit" ) {
    my $id     = $input->param('id');
    my $fields = {
        module      => scalar $input->param('module'),
        tagfield    => scalar $input->param('tagfield'),
        tagsubfield => scalar $input->param('tagsubfield'),
        filter      => scalar $input->param('filter'),
        on_existing => scalar $input->param('on_existing'),
        on_new      => scalar $input->param('on_new'),
        on_removed  => scalar $input->param('on_removed')
    };

    ModMarcPermissionsRule( $id, $fields );
    $rules = GetMarcPermissionsRules();

}
elsif ( $op eq "add" ) {
    my $fields = {
        module      => scalar $input->param('module'),
        tagfield    => scalar $input->param('tagfield'),
        tagsubfield => scalar $input->param('tagsubfield'),
        filter      => scalar $input->param('filter'),
        on_existing => scalar $input->param('on_existing'),
        on_new      => scalar $input->param('on_new'),
        on_removed  => scalar $input->param('on_removed')
    };

    AddMarcPermissionsRule($fields);
    $rules = GetMarcPermissionsRules();

}
else {
    $rules = GetMarcPermissionsRules();
}
my $modules = GetMarcPermissionsModules();
$template->param( rules => $rules, modules => $modules );

output_html_with_http_headers $input, $cookie, $template->output;
