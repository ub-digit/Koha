use Modern::Perl;

return {
    bug_number => "",
    description => "Add system preference",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};
        # Do you stuffs here
        $dbh->do(q{INSERT IGNORE INTO systempreferences (`variable`, `value`, `options`, `explanation`, `type`) VALUES ('UsePatronPreferencesForOverdue', '0', null, 'Use patron specific messaging preferences for overdue notices if available', 'YesNo')});
        # Print useful stuff here
        say $out "System preference added";
    },
}

