use Modern::Perl;

return {
    bug_number => "",
    description => "Add system preferences for define attributes with secret values (branch gub-dev-make-extended-attributes-hidable-and-not-editable)",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};
        # Do you stuffs here
        $dbh->do(q{INSERT IGNORE INTO systempreferences (`variable`, `value`, `options`, `explanation`, `type`) VALUES ('SecretExtendedAttributes', '', null, 'Define extended attributes with secret values', 'multiple')});
        $dbh->do(q{INSERT IGNORE INTO systempreferences (`variable`, `value`, `options`, `explanation`, `type`) VALUES ('SecretExtendedAttributesAdmin', '', null, 'Define extended attributes with secret values for administrators', 'multiple')});
        # Print useful stuff here
        say $out "System preference added";
    },
}
