#!/usr/bin/perl

# Copyright 2008 LibLime
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

use C4::Auth;    # checkauth, getborrowernumber.
use C4::Context;
use C4::Koha;
use C4::Circulation;
use C4::Output;
use C4::Members;
use C4::Members::Messaging;
use C4::Form::MessagingPreferences;
use Koha::Patrons;
use Koha::SMS::Providers;

my $query = CGI->new();

unless ( C4::Context->preference('EnhancedMessagingPreferencesOPAC') and
         C4::Context->preference('EnhancedMessagingPreferences') ) {
    print $query->redirect("/cgi-bin/koha/errors/404.pl");
    exit;
}

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => 'opac-messaging.tt',
        query           => $query,
        type            => 'opac',
        authnotrequired => 0,
        debug           => 1,
    }
);

my $patron = Koha::Patrons->find( $borrowernumber ); # FIXME and if borrowernumber is invalid?

my $messaging_options = C4::Members::Messaging::GetMessagingOptions();

if ( defined $query->param('modify') && $query->param('modify') eq 'yes' ) {
    # if simplified form is to be used we add the params here
    if ( defined $query->param('simple') && $query->param('simple') eq 'yes') {
        if (defined $query->param ('opacmessaging-simple-radios')) {
            my %whichActionsToTickUsingSimpleOpacMessaging = map { $_ => 1 } (split /\|/, C4::Context->preference('whichActionsToTickUsingSimpleOpacMessaging')); # split the string to array and then convert to hash to use keys for easy checking
            if ($query->param('opacmessaging-simple-radios') eq 'sms') {
                foreach my $messaging_option (@{$messaging_options})
                {
                    if ($whichActionsToTickUsingSimpleOpacMessaging{$messaging_option->{'message_name'}}) {
                        $query->param($messaging_option->{'message_attribute_id'}, "sms");
                    }
                }
            }
            elsif ($query->param('opacmessaging-simple-radios') eq 'email') {
                # set all types to email
                foreach my $messaging_option (@{$messaging_options})
                {
                    if ($whichActionsToTickUsingSimpleOpacMessaging{$messaging_option->{'message_name'}}) {
                         $query->param($messaging_option->{'message_attribute_id'}, "email");
                    }
                }
            }
            elsif (($query->param('opacmessaging-simple-radios') eq 'SmsAndEmail')) {
                 # set all types to email and sms
                foreach my $messaging_option (@{$messaging_options})
                {
                    if ($whichActionsToTickUsingSimpleOpacMessaging{$messaging_option->{'message_name'}}) {
                        $query->param($messaging_option->{'message_attribute_id'}, "sms", "email");
                    }
                }
            }
        }
    }

    my $sms = $query->param('SMSnumber');
    my $sms_provider_id = $query->param('sms_provider_id');
    if ( !defined $query->param('simple') || $query->param('simple') ne 'yes') {
    if ( defined $sms && ( $patron->smsalertnumber // '' ) ne $sms
            or ( $patron->sms_provider_id // '' ) ne $sms_provider_id ) {
        $patron->set({
            smsalertnumber  => $sms,
            sms_provider_id => $sms_provider_id,
            email           => $query->param('email'),
        })->store;
    }
    }

    C4::Form::MessagingPreferences::handle_form_action($query, { borrowernumber => $patron->borrowernumber }, $template);
}

C4::Form::MessagingPreferences::set_form_values({ borrowernumber     => $patron->borrowernumber }, $template);

$template->param(
                  messagingview         => 1,
                  SMSnumber             => $patron->smsalertnumber, # FIXME This is already sent 2 lines above
                  email => $patron->email,
                  SMSSendDriver                =>  C4::Context->preference("SMSSendDriver"),
                  TalkingTechItivaPhone        =>  C4::Context->preference("TalkingTechItivaPhoneNotification") );

if ( C4::Context->preference("SMSSendDriver") eq 'Email' ) {
    my @providers = Koha::SMS::Providers->search();
    $template->param( sms_providers => \@providers, sms_provider_id => $patron->sms_provider_id );
}

output_html_with_http_headers $query, $cookie, $template->output, undef, { force_no_caching => 1 };
