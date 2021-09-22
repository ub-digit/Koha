use Modern::Perl;

return {
    bug_number => "18138",
    description => "Add system preference",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};
        # Do you stuffs here
        $dbh->do(q{INSERT IGNORE INTO systempreferences ( `variable`, `value`, `options`, `explanation`, `type`) VALUES ('SaveBiblioMarcModificationTemplate', '', NULL, 'MARC modification template applied when saving bibliographic record in staff client or HTTP API', 'marcModTemplates')});
        # Print useful stuff here
        say $out "System preference added";
    },
}
