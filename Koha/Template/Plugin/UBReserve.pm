package Koha::Template::Plugin::UBReserve;
use Modern::Perl;
use base qw( Template::Plugin );

sub isPickup {
    my ($self, $reserve) = @_;
    return 1 if (!defined $reserve);
    my $reservenotes = $reserve->reservenotes();
    return 0 if ($reservenotes =~ /^L.netyp: Skicka hem/);
    return 1;
}

1;
