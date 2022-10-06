
use Modern::Perl;

return {
    bug_number => "",
    description => "Syspref for disabling internal statistics",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};
        # Do you stuffs here
        $dbh->do(q{INSERT IGNORE INTO systempreferences ( `variable`, `value`, `options`, `explanation`, `type`) VALUES ('DisableStatistics', '0', null, 'Disable internal statistics', 'YesNo')});
        # Print useful stuff here
        say $out "System preference added";
    },
}