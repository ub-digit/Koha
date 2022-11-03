use Modern::Perl;

return {
    bug_number => "",
    description => "Syspref for disabling online payments in My loans",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};
        # Do you stuffs here
        $dbh->do(q{INSERT IGNORE INTO systempreferences ( `variable`, `value`, `options`, `explanation`, `type`) VALUES ('DisableOnlinePayments', '0', null, 'Disable Online Payments', 'YesNo')});
        # Print useful stuff here
        say $out "System preference added";
    },
}