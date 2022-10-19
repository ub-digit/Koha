use Modern::Perl;

return {
    bug_number => "",
    description => "Add system preferences for branch gub-dev-make-extended-attributes-hidable-and-not-editable",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};
        # Do you stuffs here
        $dbh->do(q{INSERT IGNORE INTO systempreferences (`variable`, `value`, `options`, `explanation`, `type`) VALUES ('HiddenExtendedAttributes', '', null, 'Define hidden extended attributes', 'multiple')});
        $dbh->do(q{INSERT IGNORE INTO systempreferences (`variable`, `value`, `options`, `explanation`, `type`) VALUES ('HiddenExtendedAttributesAdmin', '', null, 'Define hidden extended attributes for administrators', 'multiple')});
        $dbh->do(q{INSERT IGNORE INTO systempreferences (`variable`, `value`, `options`, `explanation`, `type`) VALUES ('NonEditableExtendedAttributes', '', null, 'Define non-editable extended attributes', 'multiple')});
        $dbh->do(q{INSERT IGNORE INTO systempreferences (`variable`, `value`, `options`, `explanation`, `type`) VALUES ('NonEditableExtendedAttributesAdmin', '', null, 'Define non-editable extended attributes for administrators', 'multiple')});
        # Print useful stuff here
        say $out "System preference added";
    },
}
