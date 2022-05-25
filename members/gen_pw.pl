#!/usr/bin/perl

# Copyright 2012 ByWater Solutions
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

use Modern::Perl;

use CGI qw ( -utf8 );

use C4::Auth qw( get_template_and_user );
use C4::Output qw( output_and_exit_if_error output_and_exit output_html_with_http_headers );
use C4::Members;
use LWP::UserAgent;
use HTTP::Request::Common qw{ POST };
use JSON qw( decode_json );
use YAML::XS 'LoadFile';

use Koha::Patrons;
use Koha::Patron::Files;
use Koha::Patron::Categories;
use Data::Dumper;

my $cgi = CGI->new;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "members/gen_pw.tt",
        query           => $cgi,
        type            => "intranet",
        flagsrequired   => { borrowers => 'edit_borrowers' },
    }
);

my $borrowernumber = $cgi->param('borrowernumber');

my $logged_in_user = Koha::Patrons->find( $loggedinuser );
my $patron         = Koha::Patrons->find($borrowernumber);
output_and_exit_if_error( $cgi, $cookie, $template, { module => 'members', logged_in_user => $logged_in_user, current_patron => $patron } );

$template->param( patron => $patron );

my $configfile = $ENV{'GUB_EXTGEN_CONFIG'} || "/etc/koha/gub/extgen/config.yaml";
my $config = LoadFile($configfile);

my $extgen_url = $config->{'url'};
my $extgen_key = $config->{'key'};
my $contact_address = $config->{'contact'};
$template->param( contact_address => $contact_address );

my $ipno = $ENV{'REMOTE_ADDR'};
my $ua   = LWP::UserAgent->new();

my $request = POST(
  $extgen_url,
  [
    username => $patron->cardnumber(),
    key => $extgen_key,
    generating_entity => $ipno
  ]
);

my $response = $ua->request($request)->decoded_content;
my $result = decode_json($response);
if($result->{response} && $result->{response}->{ok}) {
  $template->param( success => 1);
} else {
  $template->param( errors => 1);
}


print STDERR Dumper(["DEBUG", $result]);

output_html_with_http_headers $cgi, $cookie, $template->output;