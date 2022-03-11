package Koha::Template::Plugin::ViewLog;

=head1 NAME

Koha::Template::Plugin::ViewLog - A module for logging when a particular template is rendered and viewed by staff.

=head1 DESCRIPTION

This plugin contains methods to log when sensitive information is viewed by staff in order to mitigate or aid in
investigating GDPR personal data breach incidents.

=head2 Methods

=head3 log_patron_view

[% Desks.log_patron_view(borrowernumber) %]

Writes to action log that a patron with C<borrowernumber> has been viewd by the current user.

=cut

use Modern::Perl;
use C4::Context;
use C4::Log qw( logaction );

use Template::Plugin;
use base qw( Template::Plugin );

sub log_patron_view {
    my ($self, $patron_borrowernumber ) = @_;
    if (C4::Context->preference('PatronViewLog')) {
        my $ip = $ENV{REMOTE_ADDR};
        my $uri = $ENV{REQUEST_URI};
        logaction(
            'MEMBERS',
            'VIEW',
            $patron_borrowernumber,
            "borrowernumber: $patron_borrowernumber, ip: $ip, uri: $uri"
        );
    }
};

1;
