#!/usr/bin/perl
use Modern::Perl;
use C4::Context;
use Getopt::Long;

my $dbh = C4::Context->dbh;

my $environment;
my $get_print_data_api_key;
my $adjustlibris_home;

GetOptions(
    'environment=s' => \$environment,
    'get_print_data_api_key=s' => \$get_print_data_api_key,
    'adjustlibris_home=s' => \$adjustlibris_home
);

my $preferences = {
    lab => {
        OPACBaseURL => 'https://koha-lab.ub.gu.se',
        patronselfregistrationlinkaddress => 'https://bibliotekskort-lab.ub.gu.se/',
        staffClientBaseURL => 'https://koha-lab-intra.ub.gu.se'
    },
    staging => {
        OPACBaseURL => 'https://koha-staging.ub.gu.se',
        patronselfregistrationlinkaddress => 'https://bibliotekskort-staging.ub.gu.se/',
        staffClientBaseURL => 'https://koha-staging-intra.ub.gu.se'
    }
};

my $marc_command = qq(bash -c 'source "$adjustlibris_home/.rvm/scripts/rvm" && cd "$adjustlibris_home/adjustlibris" && LANG=en_US.UTF-8 ./main.rb "{marc_file}" "{marc_file}.out" 2>>"/tmp/libris_import.err" && cat "{marc_file}.out" && rm "{marc_file}" "{marc_file}.out"');

my $plugin_preferences = {
    lab => {
        'Koha::Plugin::Se::Gu::Ub::GetPrintData' => {
            api_url => 'https://bestall-lab.ub.gu.se/api/print',
            api_key => $get_print_data_api_key,
        },
        'Koha::Plugin::Se::Ub::Gu::MarcImport' => {
            run_marc_command_command => $marc_command,
        }
    },
    staging => {
        'Koha::Plugin::Se::Gu::Ub::GetPrintData' => {
            api_url => 'https://bestall-staging.ub.gu.se/api/print',
            api_key => $get_print_data_api_key,
        },
        'Koha::Plugin::Se::Ub::Gu::MarcImport' => {
            run_marc_command_command => $marc_command,
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
