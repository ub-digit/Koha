use Modern::Perl;

return {
    bug_number => "30279",
    description => "Add' PatronViewLog' system preference",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};
        $dbh->do(q{ INSERT IGNORE INTO systempreferences (variable, value, options, explanation, type) VALUES ('PatronViewLog', '0', NULL, 'If enabled, log when patron personal data is viewed in staff interface', 'YesNo') });
        say $out "System preference added";
    },
};
