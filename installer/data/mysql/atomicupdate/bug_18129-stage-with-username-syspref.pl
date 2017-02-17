use Modern::Perl;

return {
    bug_number => "18129",
    description => "Add system preference",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};
        # Do you stuffs here
        $dbh->do(q{INSERT IGNORE INTO systempreferences ( `variable`, `value`, `options`, `explanation`, `type`) VALUES ('StageFilterByUser', '0', '', 'Filter staged batches by user', 'YesNo')});
        $dbh->do(q{INSERT IGNORE INTO systempreferences ( `variable`, `value`, `options`, `explanation`, `type`) VALUES ('StageHideCleanedImported', '0', '', 'Hide staged batches when cleaned or imported', 'YesNo')});
        # Print useful stuff here
        say $out "System preference added";
    },
}
