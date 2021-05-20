#!/usr/bin/perl
use Modern::Perl;
#use utf8;
use C4::Context;
use Koha::Database;
use Koha::Patrons;
use Koha::Patron::Messages;
use Data::Dumper;
use List::Util qw(shuffle);

my $dbh = C4::Context->dbh;
my $rows;

my $patrons = Koha::Patrons->search({
    -or => [ 'flags' => undef, 'flags' => { '<', 1 } ]
});

# Patrons
while (my $patron = $patrons->next) {
    my $scrambled_patron = {};
    # Patron fields to anonymize
    for my $property (qw(
        surname
        firstname
        cardnumber
        address
        address2
        city
        zipcode
        streetnumber
        userid
        smsalertnumber
        email
        phone
        )) {
        if ($patron->get_column($property)) {
            $scrambled_patron->{$property} = obfuscate_string($patron->get_column($property));
        }
    }
    # Patron fields to remove
    for my $property (qw(
        country
        mobile
        fax
        emailpro
        phonepro
        B_streetnumber
        B_streettype
        B_address
        B_address2
        B_city
        B_state
        B_zipcode
        B_country
        B_email
        B_phone
        contactname
        contactfirstname
        contacttitle
        flags
        contactnote
        altcontactfirstname
        altcontactsurname
        altcontactaddress1
        altcontactaddress2
        altcontactaddress3
        altcontactstate
        altcontactzipcode
        altcontactcountry
        altcontactphone
        password
        )) {
        $scrambled_patron->{$property} = undef;
    }
    $patron->set($scrambled_patron);
    $patron->store();
}

my $sms_providers = Koha::SMS::Providers->search;

while (my $sms_provider = $sms_providers->next) {
    # Not really needed since using local mailhog
    $sms_provider->set({'domain' => 'example.com'});
    $sms_provider->store();
}

my $attributes_to_be_deleted = Koha::Patron::Attributes->search({
    code => { -in => ['INVCNT', 'PRINT', 'GKNR', 'GPNR'] }
});
$attributes_to_be_deleted->delete;

$rows = $dbh->do(q{
    UPDATE `borrower_attributes`
    SET `attribute` = '2099-21-31'
    WHERE `code` = 'ANSTSLUT' AND STR_TO_DATE(attribute, '%Y-%m-%d') > NOW()
}) or die $dbh->errstr;
printf "borrower_attributes %d rows updated\n", $rows;

$rows = $dbh->do(q{
    DELETE FROM `borrower_attributes`
    WHERE `code` = 'ANSTSLUT' AND STR_TO_DATE(attribute, '%Y-%m-%d') < NOW()
}) or die $dbh->errstr;
printf "borrower_attributes %d rows deleted\n", $rows;

my $pnr_attributes = Koha::Patron::Attributes->search({
    code => { -in => ['PNR12', 'PNR'] }
})->_resultset; # Bypass silly/buggy Koha repeatable check

while (my $attribute = $pnr_attributes->next) {
    my $value = obfuscate_numeric($attribute->get_column('attribute'));
    $attribute->update({'attribute' => $value});
}

$rows = $dbh->do(q{
    DELETE `m`
    FROM `messages` AS `m`
    JOIN `borrowers` AS `b`
    ON `m`.`borrowernumber` = `b`.`borrowernumber`
    WHERE `b`.`flags` IS NULL OR `b`.`flags` < ?
}, undef, 1)  or die $dbh->errstr;

printf "messages %d rows deleted\n", $rows;

$rows = $dbh->do(q{
    DELETE `m`
    FROM `message_queue` AS `m`
    JOIN `borrowers` AS `b`
    ON `m`.`borrowernumber` = `b`.`borrowernumber`
    WHERE `b`.`flags` IS NULL OR `b`.`flags` < ?
}, undef, 1)  or die $dbh->errstr;

printf "message_queue %d rows deleted\n", $rows;

$rows = $dbh->do("DELETE FROM `action_logs`")  or die $dbh->errstr;
printf "action_logs %d rows deleted\n", $rows;

sub obfuscate_numeric {
    my ($value) = @_;
    # Just swap out numbers with fixed mapping
    $value =~ tr/0-9/5086431297/;
    return $value;
}

sub obfuscate_string {
    my ($value) = @_;
    # ROT13 "encryption" with added rotation for numbers
    # Performed twice with result in original value
    $value =~ tr/N-ZA-Mn-za-m0-45-9/A-Za-z5-90-4/;
    return $value;
}
