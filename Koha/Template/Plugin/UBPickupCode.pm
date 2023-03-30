package Koha::Template::Plugin::UBPickupCode;
use Modern::Perl;
use Template::Plugin;
use base qw( Template::Plugin );
use C4::Koha;
use C4::Context;

# Fetch the patron's first name and last name from the borrower map
# and return the last name and first name initials.
# If either the first name or last name is missing, return an empty string for that initial.
sub getPatronInitials {
    my ($patron) = @_;
    my $firstName = $patron->firstname();
    my $lastName = $patron->surname();
    my $initials = "";
    if($lastName) {
        $initials .= substr($lastName, 0, 1);
    }
    if($firstName) {
        $initials = substr($firstName, 0, 1);
    }
    return $initials;
}

# Get the patrons initials, and the last 4 digits of the cardnumber
# and return that as the patron's pickup code
sub PickupCode {
    my ($self, $patron) = @_;
    my $initials = getPatronInitials($patron);
    my $cardnumber = $patron->cardnumber();
    my $last4 = substr($cardnumber, -4);
    return $initials . $last4;
}

1;
