#!/usr/bin/perl
use Modern::Perl;
use C4::Context;

my $dbh = C4::Context->dbh;

my $environment = $ARGV[0];

my $preferences = {
    lab => {
        OPACBaseURL => 'https://minalan-lab.ub.gu.se',
        patronselfregistrationlinkaddress => 'https://bibliotekskort.ub.gu.se/',
        staffClientBaseURL => 'https://koha-lab-intra.ub.gu.se'
    },
    staging => {
        OPACBaseURL => 'https://minalan-staging.ub.gu.se',
        patronselfregistrationlinkaddress => 'https://bibliotekskort-staging.ub.gu.se/',
        staffClientBaseURL => 'https://koha-staging-intra.ub.gu.se'
    }
};

my $plugin_preferences = {
    lab => {
        'Koha::Plugin::Se::Gu::Ub::GetPrintData' => {
            api_url => 'https://bestall-lab.ub.gu.se/api/print'
        },
    },
    staging => {
        'Koha::Plugin::Se::Gu::Ub::GetPrintData' => {
            api_url => 'https://bestall-staging.ub.gu.se/api/print'
        },
    }
};

while (my ($pref, $value) = each %{$preferences->{$environment}}) {
    $dbh->do(q{
        UPDATE `systempreferences` SET `value` = ? WHERE `variable` = ?
        }, undef, $value, $pref) or die $dbh->errstr;
}

while (my ($plugin_class, $settings) = each %{$plugin_preferences->{$environment}}) {
    while (my ($plugin_key, $plugin_value) = each %{$settings}) {
        $dbh->do(q{
            UPDATE `plugin_data` SET `plugin_value` = ?
            WHERE `plugin_class` = ? AND `plugin_key` = ?
            }, undef, $plugin_value, $plugin_class, $plugin_key) or die $dbh->errstr;
    }
}
