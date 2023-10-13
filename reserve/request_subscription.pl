#!/usr/bin/perl


#written 2/1/00 by chris@katipo.oc.nz
# Copyright 2000-2002 Katipo Communications
# Parts Copyright 2011 Catalyst IT
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

=head1 request.pl

script to place reserves/requests

=cut

use Modern::Perl;

use CGI qw ( -utf8 );
use List::MoreUtils qw( uniq );
use Date::Calc qw( Date_to_Days );
use C4::Output qw( output_html_with_http_headers );
use C4::Auth qw( get_template_and_user );
use C4::Reserves qw( RevertWaitingStatus AlterPriority ToggleLowestPriority ToggleSuspend CanBookBeReserved GetMaxPatronHoldsForRecord CanItemBeReserved IsAvailableForItemLevelRequest );
use C4::Koha qw( getitemtypeimagelocation );
use C4::Serials qw( CountSubscriptionFromBiblionumber );
use C4::Circulation qw( _GetCircControlBranch GetBranchItemRule );
use Koha::DateUtils qw( dt_from_string );
use C4::Search qw( enabled_staff_search_views );
use C4::Serials qw( CountSubscriptionFromBiblionumber SearchSubscriptions GetLatestSerials );

use Koha::Biblios;
use Koha::Checkouts;
use Koha::Holds;
use Koha::CirculationRules;
use Koha::Libraries;
use Koha::Patrons;
use Koha::Patron::Attribute::Types;
use Koha::Clubs;
use Koha::BackgroundJob::BatchCancelHold;

use Data::Dumper;

my $dbh = C4::Context->dbh;
my $input = CGI->new;
my ( $template, $borrowernumber, $cookie, $flags ) = get_template_and_user(
    {
        template_name   => "reserve/request_subscription.tt",
        query           => $input,
        type            => "intranet",
        flagsrequired   => { reserveforothers => 'place_holds' },
    }
);

my $showallitems = $input->param('showallitems');
my $pickup = $input->param('pickup');

my $itemtypes = {
    map {
        $_->itemtype =>
          { %{ $_->unblessed }, image_location => $_->image_location('intranet'), notforloan => $_->notforloan }
    } Koha::ItemTypes->search_with_localization->as_list
};

# Select borrowers infos
my $findborrower = $input->param('findborrower');
$findborrower = '' unless defined $findborrower;
$findborrower =~ s|,| |g;
my $findclub = $input->param('findclub');
$findclub = '' unless defined $findclub && !$findborrower;
my $borrowernumber_hold = $input->param('borrowernumber') || '';
my $club_hold = $input->param('club')||'';
my $messageborrower;
my $messageclub;
my $warnings;
my $messages;
my $exceeded_maxreserves;
my $exceeded_holds_per_record;

my $action = $input->param('action');
$action ||= q{};

if ($findborrower) {
    my $patron = Koha::Patrons->find( { cardnumber => $findborrower } );
    $borrowernumber_hold = $patron->borrowernumber if $patron;
}

my @biblionumbers = $input->multi_param('biblionumber');

# my $multi_hold = @biblionumbers > 1;
# $template->param(
#     multi_hold => $multi_hold,
# );

# If we have the borrowernumber because we've performed an action, then we
# don't want to try to place another reserve.
if ($borrowernumber_hold && !$action) {
    my $patron = Koha::Patrons->find( $borrowernumber_hold );
    my $diffbranch = 0;

    my $amount_outstanding = $patron->account->balance;
    $template->param(
                patron              => $patron,
                diffbranch          => $diffbranch,
                messages            => $messages,
                warnings            => $warnings,
                amount_outstanding  => $amount_outstanding,
    );
}

# unless ( $club_hold or $borrowernumber_hold ) {
#     $template->param( clubcount => Koha::Clubs->search->count );
# }

# $template->param(
#     messageborrower => $messageborrower,
#     messageclub     => $messageclub
# );

# Load the hold list if
#  - we are searching for a patron or club and found one
#  - we are not searching for anything
if (( $findborrower && $borrowernumber_hold ) || !$findborrower) {
    my $patron = Koha::Patrons->find( $borrowernumber_hold );
    my $logged_in_patron = Koha::Patrons->find( $borrowernumber );

    my $wants_check;
    my $itemdata_enumchron = 0;
    my $itemdata_ccode = 0;
    my @biblioloop = ();
    my $no_reserves_allowed = 0;
    my $num_bibs_available = 0;
    foreach my $biblionumber (@biblionumbers) {
        next unless $biblionumber =~ m|^\d+$|;

        my %biblioloopiter = ();

        my $biblio = Koha::Biblios->find( $biblionumber );

        unless ($biblio) {
            $biblioloopiter{nosubscriptions} = 1;
            $template->param('nobiblio' => 1);
            last;
        }

        $biblioloopiter{object} = $biblio;

        my @subscriptions = SearchSubscriptions({ biblionumber => $biblionumber, orderby => 'title' });

        unless ( @subscriptions ) {
            # FIXME Then why do we continue?
            $template->param('nosubscriptions' => 1);
            $biblioloopiter{nosubscriptions} = 1;
        }

        if ( $borrowernumber_hold ) {
            my @available_itemtypes;
            my $num_items_available = 0;
            my $num_override  = 0;
            my $hiddencount   = 0;
            my $num_alreadyheld = 0;

            # iterating through all items first to check if any of them available
            # to pass this value further inside down to IsAvailableForItemLevelRequest to
            # it's complicated logic to analyse.
            # (before this loop was inside that sub loop so it was O(n^2) )

            for my $subscription ( @subscriptions ) {
                my $do_check;

                if($subscription->{biblionumber} ne $biblio->biblionumber){
                    $subscription->{hosttitle} = Koha::Biblios->find( $subscription->{biblionumber} )->title;
                }

                $subscription->{subscriptionnotes} = $subscription->{internalnotes};

                if ( $patron ) {
                    my $default_hold_pickup_location_pref = C4::Context->preference('DefaultHoldPickupLocation');
                    my $default_pickup_branch;
                    if( $default_hold_pickup_location_pref eq 'homebranch' ){
                        $default_pickup_branch = $subscription->{branchcode};
                    } elsif ( $default_hold_pickup_location_pref eq 'holdingbranch' ){
                        $default_pickup_branch = $subscription->{branchcode};
                    } else {
                        $default_pickup_branch = C4::Context->userenv->{branch};
                    }

                    my $pickup_libraries = Koha::Libraries->search();
                    my $pickup_locations = $pickup_libraries->search({pickup_location => 1},{order_by => ['branchname']});
                    my $default_pickup_location = $pickup_locations->search({ branchcode => $default_pickup_branch })->next;
                    $subscription->{default_pickup_location} = $default_pickup_location;
                }

                push @{ $biblioloopiter{subscriptionloop} }, $subscription;
            }

            $biblioloopiter{biblioitem} = $biblio->biblioitem;
        }

        # get the time for the form name...
        my $time = time();

        $template->param(
                         time        => $time,
                        );

        # display infos
        $template->param(
                         date              => dt_from_string,
                         biblionumber      => $biblionumber,
                         findborrower      => $findborrower,
                         biblio            => $biblio,
                         subscriptioncount => scalar @subscriptions,
                         C4::Search::enabled_staff_search_views,
                        );

        $biblioloopiter{biblionumber} = $biblionumber;
        $biblioloopiter{title}  = $biblio->title;
        $biblioloopiter{author} = $biblio->author;

        $num_bibs_available++ unless $biblioloopiter{none_avail};
        push @biblioloop, \%biblioloopiter;
    }

    $template->param( no_bibs_available => 1 ) unless $num_bibs_available > 0;

    $template->param( biblioloop => \@biblioloop );
    $template->param( subscriptionsnumber => CountSubscriptionFromBiblionumber($biblionumbers[0]));
} else {
    my $biblio = Koha::Biblios->find( $biblionumbers[0] );
    $template->param( biblio => $biblio );
}
$template->param( biblionumbers => \@biblionumbers );

$template->param(
    attribute_type_codes => ( C4::Context->preference('ExtendedPatronAttributes')
        ? [ Koha::Patron::Attribute::Types->search( { staff_searchable => 1 } )->get_column('code') ]
        : []
    ),
);


# pass the userenv branch if no pickup location selected
$template->param( pickup => $pickup || C4::Context->userenv->{branch} );

$template->param(borrowernumber => $borrowernumber_hold);

# printout the page
output_html_with_http_headers $input, $cookie, $template->output;

sub sort_borrowerlist {
    my $borrowerslist = shift;
    my $ref           = [];
    push @{$ref}, sort {
        uc( $a->{surname} . $a->{firstname} ) cmp
          uc( $b->{surname} . $b->{firstname} )
    } @{$borrowerslist};
    return $ref;
}
