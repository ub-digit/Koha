package Koha::Template::Plugin::UBLibraryProperties;
use Modern::Perl;
use Koha::AuthorisedValues;
use base qw( Template::Plugin );

sub shortName {
my ($self, $branchcode, $language) = @_;
  return getName('LIBRARY_SHORT_NAME', $branchcode, $language);
}

sub longName {
my ($self, $branchcode, $language) = @_;
  return getName('LIBRARY_LONG_NAME', $branchcode, $language);
}

sub getName {
my ($category, $branchcode, $language) = @_;
    my $av = Koha::AuthorisedValues->search({ category => $category, authorised_value => $branchcode });
    if ($av->count) {
        return ($language eq "en") ? $av->next->lib_opac : $av->next->lib;
    }
    else {
        # TODO: Fallback?
        return '';
    }
}

1;
