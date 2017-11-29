use Modern::Perl;

return {
    bug_number => "",
    description => "Add system preference",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};
        # Do you stuffs here
        $dbh->do(q{INSERT IGNORE INTO systempreferences ( `variable`, `value`, `options`, `explanation`, `type`) VALUES ('AcqUncertainPriceWhenImporting','1',NULL,'if yes it will set the uncertainprice to 1 else 0','YesNo')});
        # Print useful stuff here
        say $out "System preference added";
    },
}
