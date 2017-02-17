use Modern::Perl;

return {
    bug_number => "18129",
    description => "Add system preference",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};
        # Do you stuffs here
        $dbh->do(q{ALTER TABLE `import_batches` ADD `borrowernumber` int(11)});
        # Print useful stuff here
        say $out "Table import_batches altered";
    },
}
