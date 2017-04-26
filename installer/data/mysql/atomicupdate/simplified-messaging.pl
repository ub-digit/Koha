use Modern::Perl;

return {
    bug_number => "",
    description => "Add system preference",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};
        # Do you stuffs here
        $dbh->do(q{INSERT IGNORE INTO systempreferences ( `variable`, `value`, `options`, `explanation`, `type`) VALUES ('enableSimpleMessaging', '0', null, 'Toggle simple form of messaging options', 'YesNo')});
        $dbh->do(q{INSERT IGNORE INTO systempreferences ( `variable`, `value`, `options`, `explanation`, `type`) VALUES ('whichActionsToTickUsingSimpleMessaging','Advance_Notice|Hold_Filled|Overdue1|Overdue2',NULL,'A list of which messaging to set ','free')});
        # Print useful stuff here
        say $out "System preference added";
    },
}
