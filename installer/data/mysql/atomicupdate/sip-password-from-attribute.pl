use Modern::Perl;

return {
    bug_number => "",
    description => "Add system preference SIPPasswordFromAttribute",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};
        # Do you stuffs here
        $dbh->do(q{INSERT IGNORE INTO systempreferences ( `variable`, `value`, `options`, `explanation`, `type`) VALUES ('SIPPasswordFromAttribute', '0', '', 'Use patron attribute as password in SIP requests', 'YesNo')});
        $dbh->do(q{INSERT IGNORE INTO systempreferences ( `variable`, `value`, `options`, `explanation`, `type`) VALUES ('SIPPasswordAttribute', '', '', 'Patron attribute to use as password in SIP requests', 'Free')});
        # Print useful stuff here
        say $out "System preference SIPPasswordFromAttribute added";
    },
}
