#!/usr/bin/perl

#script to place reserves/requests
#written 2/1/00 by chris@katipo.oc.nz


# Copyright 2000-2002 Katipo Communications
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
use URI;
use C4::Reserves qw( CanItemBeReserved AddReserve CanBookBeReserved );
use C4::Auth qw( checkauth );
use C4::Serials qw( GetSubscription );

use Koha::Items;
use Koha::Patrons;

use Data::Dumper;

my $input = CGI->new();

checkauth($input, 0, { reserveforothers => 'place_holds' }, 'intranet');

my @biblionumbers   = $input->multi_param('biblionumber');
my $borrowernumber = $input->param('borrowernumber');
my $notes          = $input->param('notes');
my $branch         = $input->param('pickup');
my $title          = $input->param('title');
my $subscription_id      = $input->param('checksubscription');

my $patron = Koha::Patrons->find( $borrowernumber );
my $request_error = undef;

my $holds_to_place_count = $input->param('holds_to_place_count') || 1;

my %bibinfos = ();
foreach my $bibnum ( @biblionumbers ) {
    my %bibinfo = ();
    $bibinfo{title}  = $input->param("title_$bibnum");
    $bibinfo{rank}   = $input->param("rank_$bibnum");
    $bibinfo{pickup} = $input->param("pickup_$bibnum");
    $bibinfos{$bibnum} = \%bibinfo;
}

my $found;

if ( $patron ) {

    foreach my $biblionumber ( keys %bibinfos ) {
      my $subscription = GetSubscription($subscription_id);

      # There really is only one biblionumber, but we're using the same
      # code as in the multiple holds case.

      # The goal here is to send the request to an external URL in a POST
      # request.
      # The data provided to the external URL is:
      # username - The username of the patron the request is for
      # performer - The staff member who placed the request
      # reserve.user_id - The borrowernumber of the patron the request is for
      # reserve.biblio_id - The biblionumber of the subscription
      # reserve.subscription_location - The library owning the subscription (text, not code)
      # reserve.subscription_sublocation - The LOC text of the subscription
      # reserve.subscription_sublocation_id - The LOC code of the subscription
      # reserve.subscription_call_number - The callnumber of the subscription
      # reserve.subscription_notes - The notes of the subscription
      # reserve.location_id - The pickup library code.

      # The URL to the external URL is defined in the koha-conf.xml file
      # as the value of the <subscription_request_url> tag.

      my $subscription_branch = Koha::Libraries->find($subscription->{branchcode});
      my $subscription_branchname = $subscription_branch->branchname;

      my $subscription_location = Koha::AuthorisedValues->find({ category => 'LOC', authorised_value => $subscription->{location} });
      my $subscription_sublocation = $subscription_location->lib_opac;
      my $subscription_sublocation_id = $subscription_location->authorised_value;

      # Always use cardnumber, since it is guaranteed to exist, and the lookup from this value will
      # always fall back to checking that field.
      my $username = $patron->cardnumber;
      my $performer_cardnumber = C4::Context->userenv->{cardnumber};
      my $performer = Koha::Patrons->find( { cardnumber => $performer_cardnumber } );
      my $performer_borrowernumber = $performer->borrowernumber;

      my $external_url = C4::Context->config('subscription_request_url');
      my $external_url_apikey = C4::Context->config('subscription_request_apikey');

      my $request_obj = {
        api_key => $external_url_apikey,
        username => $username,
        performer => $performer_borrowernumber,
        'reserve[user_id]' => $borrowernumber,
        'reserve[biblio_id]' => $biblionumber,
        'reserve[subscription_location]' => $subscription_branchname,
        'reserve[subscription_sublocation]' => $subscription_sublocation,
        'reserve[subscription_sublocation_id]' => $subscription_sublocation_id,
        'reserve[subscription_call_number]' => $subscription->{callnumber},
        'reserve[subscription_notes]' => $notes,
        'reserve[location_id]' => $branch,
      };

      # Call the external URL with the data provided above.

      my $ua = LWP::UserAgent->new;
      my $response = $ua->post($external_url, $request_obj);
      if (! $response->is_success) {
        $request_error = $response->status_line;
      }
    }

    if ( $request_error ) {
      print $input->header();
      print "Kunde inte skapa reservation: $request_error";
    } else {
      my $redirect_url = URI->new("request_subscription.pl");
      $redirect_url->query_form( biblionumber => [@biblionumbers]);
      print $input->redirect($redirect_url);
    }
}
elsif ( $borrowernumber eq '' ) {
    print $input->header();
    print "Invalid borrower number please try again";

    # Not sure that Dump() does HTML escaping. Use firebug or something to trace
    # instead.
    #print $input->Dump;
}
